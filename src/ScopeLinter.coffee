"use strict"
normalize = require "./globals"
Visitor = require "./Visitor"


module.exports = class ScopeLinter extends Visitor
    STATE_READ: "read"
    STATE_WRITE: "write"

    @default: -> defaultLinter  # initialized on the bottom of the file

    constructor: ->
        super()
        @init()

    init: =>
        # stack of function scopes available in the current node; a new empty
        # scope is pushed every time a Code node is encountered and popped
        # every time a Code node has been completely visited.
        @scopes = []

        # the current scope, if any
        @scope = null

        # stack of variable definitions to insert in the current scope; a new
        # empty list is pushed every time an Assign node is encountered and the
        # (populated) list is popped and merged into the current scope every
        # time an Assign node has been completely visited.
        @definitions = []

        # the current set of definitions, if any (last value in @definitions)
        @currentDefinitions = null

        # the current AST depth
        @depth = 0

        # whether a Value node is expected to read an existing value, overwrite
        # a value (new or existing) or shadow another value in a higher scope
        @state = @STATE_READ

    lint: (root, @options) =>
        try
            @errors = []
            @walk(root)
            return @errors
        catch e
            @init()  # revert linter to post-constructor state
            throw e
        finally
            delete @options
            delete @errors

    getScope: (name) =>
        # Returns the nearest scope that contains a variable called `name`
        for index in [@scopes.length - 1..0]
            scope = @scopes[index]
            if scope[name]?
                return scope

    identifierAccessed: (node, name) =>
        scope = @getScope(name)

        if scope?
            scope[name].read = true
        else if @options["undefined"]
            @errors.push({
                # context: node.base.locationData
                lineNumber: node.base.locationData.first_line + 1
                message: "Undefined identifier '#{name}'"
            })

        if node.hasProperties()
            for prop in node.properties
                if prop.constructor.name is "Index"
                    old = @state
                    @state = @STATE_READ
                    @walk(prop)
                    @state = old

    identifierAssigned: (node, name, silent = false) =>
        scope = @getScope(name)
        if scope?
            {written, type} = scope[name]
            if type is "Builtin"
                # coffeescript provides no direct way to assign to a builtin
                # variable; a new value is created in the current scope instead
                return @identifierShadowed(node, name, silent)

            if not silent and (scope isnt @scope or @options["same_scope"])
                @errors.push({
                    # context: node.locationData
                    lineNumber: node.locationData.first_line + 1
                    message: "Overwriting variable '#{name}' (first defined
                              on line #{written[0].first_line + 1})"
                })
        else
            # create new variable in current scope
            @scope[name] = {
                type: "Variable"
                read: false
                written: []
            }
            scope = @scope

        scope[name].written.push(node.locationData)

    identifierShadowed: (node, name, silent = false) =>
        scope = @getScope(name)
        if \
                scope? and not silent and @options["shadow"] and \
                name not in (@options["shadow_exceptions"] or [])
            {written, type} = scope[name]
            if (type isnt "Builtin" or @options["shadow_builtins"])
                @errors.push({
                    # context: node.locationData
                    lineNumber: node.locationData.first_line + 1
                    message: if type is "Builtin"
                        "Shadowing built-in variable '#{name}'"
                    else
                        "Shadowing variable '#{name}' (first defined on
                         line #{written[0].first_line + 1})"
                })

        @scope[name] = {
            type: "Argument"
            read: false
            written: [node.locationData]
        }

    nodeEnter: (node) =>
        if node.constructor.name is "Block" and @depth is 0
            # start of root block; push global scope
            @scope = {}
            globals = normalize(@options["environments"], @options["globals"])
            for name of globals
                @scope[name] = {
                    type: "Builtin"
                    written: [node.locationData]
                }
            @scopes.push(@scope)

        if node.constructor.name is "Code"
            # if a function is defined as part of an assignment statement, a
            # faux scope is created that contains all the current assignments
            # to allow for recursive references

            @scope = {}
            if @currentDefinitions?
                for [node_, name] in @currentDefinitions
                    @identifierAssigned(node_, name, true)
            @scopes.push(@scope)

            @currentDefinitions = []
            @definitions.push(@currentDefinitions)

            # start of new function; push local scope
            @scope = {
                "arguments": {
                    type: "Builtin"
                    written: [node.locationData]
                }
            }
            @scopes.push(@scope)

        @depth++

        if node.constructor.name in ["Assign", "Param"]
            # new assignment statement; remember definitions until the node is
            # completely visited
            @currentDefinitions = []
            @definitions.push(@currentDefinitions)

        if node.constructor.name is "For"
            if node.name?
                @identifierAssigned(node.name, node.name.value)
            if node.index?
                @identifierAssigned(node.index, node.index.value)

        if node.constructor.name is "Param"
            # params always exist in the function's scope and shadow without
            # overwriting all other variables
            old = @state
            if node.name.constructor.name is "Literal"
                # work around coffeescript not producing Value nodes for all
                # types of args (simple ones are just stored as Literal nodes)
                @currentDefinitions.push([node, node.name.value])
            else
                @state = @STATE_WRITE
                @walk(node.name)
                @state = @STATE_READ
            if node.value?
                @walk(node.value)
            @state = old
            return false

        if node.constructor.name is "Try"
            if node.errorVariable?
                if node.errorVariable.constructor.name is "Literal"
                    # work around coffeescript not producing Value nodes for
                    # all types of error variables (simple ones are just stored
                    # as Literal nodes)
                    @identifierAssigned(node.errorVariable,
                                        node.errorVariable.value)
                else
                    old = @state
                    @state = @STATE_WRITE
                    @currentDefinitions = []
                    @definitions.push(@currentDefinitions)
                    @walk(node.errorVariable)
                    defined = @definitions.pop()
                    @currentDefinitions = @definitions[@definitions.length - 1]
                    for [node_, name] in defined
                        @identifierAssigned(node_, name)
                    @state = old
            @walk(node.attempt)
            if node.recovery?
                @walk(node.recovery)
            if node.ensure?
                @walk(node.ensure)
            return false

        if node.constructor.name is "Assign"
            old = @state
            @state = @STATE_WRITE
            @walk(node.variable)
            @state = @STATE_READ
            @walk(node.value)
            @state = old
            return false

        if node.constructor.name is "Class"
            # a named class produces a variable in the local scope and in this
            # regard acts like an assignment statement
            if node.variable? and node.variable.base.isAssignable()
                @identifierAssigned(node.variable, node.variable.base.value)

            # a class expression (named or otherwise) can be a part of an
            # existing assignment statement; when this happens the variable(s)
            # won't receive a scope until after the assignment statement is
            # completed which means it won't be visible to inner functions
            # to work around this, a faux scope is created that contains all of
            # the variables that are supposed to be assigned in the parent node
            @scope = {}
            if @currentDefinitions?
                for [node_, name] in @currentDefinitions
                    @identifierAssigned(node_, name, true)
            @scopes.push(@scope)

            @currentDefinitions = []
            @definitions.push(@currentDefinitions)

            old = @state
            @state = @STATE_READ
            if node.parent?
                @walk(node.parent)
            @walk(node.body)
            @state = old

            @definitions.pop()
            @currentDefinitions = @definitions[@definitions.length - 1]

            @scopes.pop()
            @scope = @scopes[@scopes.length - 1]
            return false

        if node.constructor.name is "Obj" and @state is @STATE_READ
            for prop in node.properties
                if prop.constructor.name is "Assign"
                    @walk(prop.value)
                else
                    @walk(prop)

            return false

        if \
                node.constructor.name is "Value" and \
                node.base.constructor.name is "Literal" and \
                node.isAssignable()
            name = node.base.value

            if @state is @STATE_READ or node.hasProperties()
                # an attempt (either direct or via a property) was made to read
                # a variable; this may result in an undefined identifier error
                @identifierAccessed(node, name)
            else
                # this results in either an overwrite or the shadowing of an
                # existing variable from an outer scope; both use def lists
                @currentDefinitions.push([node, name])
                
            return false

        return undefined

    nodeExit: (node) =>
        @depth--

        if \
                node.constructor.name is "Code" or \
                (node.constructor.name is "Block" and @depth is 0)
            # end of function (or of root block); pop one scope...
            scope = @scopes.pop()
            @scope = @scopes[@scopes.length - 1]

            # ... and test for unused vars
            for name, {type, read, written} of scope
                if not read and @options["unused_#{type.toLowerCase()}s"]
                    for location in written
                        @errors.push({
                            # context: location
                            lineNumber: location.first_line + 1
                            message: "#{type} '#{name}' is never read (first
                                      defined on line
                                      #{written[0].first_line + 1})"
                        })

        if node.constructor.name is "Code"
            # pop the faux scope and definitions that were injected for this
            # function
            @definitions.pop()
            @currentDefinitions = @definitions[@definitions.length - 1]

            @scopes.pop()
            @scope = @scopes[@scopes.length - 1]

        if node.constructor.name is "Assign"
            # for all variables enqueued for (a potentially destructured)
            # assignment, find a variable matching that name in the nearest
            # scope and overwrite it, defaulting to creating a new variable in
            # the current scope if no matches are found
            defined = @definitions.pop()
            @currentDefinitions = @definitions[@definitions.length - 1]

            for [node_, name] in defined
                @identifierAssigned(node_, name)

        if node.constructor.name is "Param"
            # for all variables enqueued for destructuring from a param
            # expression, add a new variable with that name in the current
            # scope (which is always the function's scope as Param nodes are
            # direct descendants of Code nodes)
            defined = @definitions.pop()
            @currentDefinitions = @definitions[@definitions.length - 1]

            for [node_, name] in defined
                @identifierShadowed(node_, name)


defaultLinter = new ScopeLinter()
