"use strict"
normalize = require "./globals"


module.exports = class ScopeLinter
    @default: -> defaultLinter  # initialized on the bottom of the file

    constructor: ->
        # the scope available in the current node; a new scope is pushed every
        # time a Code node is encountered and popped every time a Code node has
        # been completely visited.
        @scope = null

        # a list of all available scopes; always ends with @scope
        @scopes = []

        # a list of variable definitions to insert in the current scope;
        # created whenever a (possibly destructured) assignment is encountered
        # the list of definitions is popped and merged into the current scope
        # every time an Assign node has been completely visited.
        @definitions = null

        # whether a Value node is expected to read an existing value, or create
        # a new variable (either by shadowing or overwriting)
        @reading = true

        # the current AST depth
        @depth = 0

    lint: (root, @options) =>
        try
            @errors = []
            @visit(root)
            return @errors
        catch e
            @constructor.apply(this)  # revert linter to post-constructor state
            throw e
        finally
            delete @options
            delete @errors

    newState: (reading, definitions, cb) =>
        # invokes `cb()` in a new state defined by `reading` and `definitions`
        # and restores the previous state when cb exists
        old = [@reading, @definitions]
        [@reading, @definitions] = [reading, definitions]
        cb()
        [@reading, @definitions] = old

    newScope: (silent, cb) =>
        # invokes `cb()` in a new empty scope and restores the previous scope
        # when cb exists; if `silent` is falsy (default), all variables tha
        # were defined in the scope are tested for access and an error is
        # created for every variable that hasn't been read (as they become
        # invisible to all other code)
        if typeof silent is "function"
            cb = silent
            silent = false

        @scope = {}
        @scopes.push(@scope)
        cb()
        scope = @scopes.pop()
        @scope = @scopes[@scopes.length - 1] or null

        if not silent
            # ... and check it for for unused vars
            for name, {type, read, written} of scope
                if not read and @options["unused_#{type.toLowerCase()}s"]
                    for location in written
                        @errors.push({
                            # context: location
                            lineNumber: location.first_line + 1
                            message: "#{type} \"#{name}\" is never read (
                                      first defined on line
                                      #{written[0].first_line + 1})"
                        })

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
                message: "Undefined identifier \"#{name}\""
            })

    identifierAssigned: (node, name) =>
        scope = @getScope(name)
        if scope?
            {written, type} = scope[name]
            if type is "Builtin"
                # coffeescript provides no direct way to assign to a builtin
                # variable; a new value is created in the current scope instead
                return @identifierShadowed(node, name)

            if \
                    @options["overwrite"] and
                    (scope isnt @scope or @options["same_scope"])
                @errors.push({
                    # context: node.locationData
                    lineNumber: node.locationData.first_line + 1
                    message: "Overwriting identifier \"#{name}\" (first defined
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

    identifierShadowed: (node, name) =>
        scope = @getScope(name)
        if \
                scope? and \
                @options["shadow"] and \
                name not in (@options["shadow_exceptions"] or [])
            {written, type} = scope[name]
            if (type isnt "Builtin" or @options["shadow_builtins"])
                @errors.push({
                    # context: node.locationData
                    lineNumber: node.locationData.first_line + 1
                    message: if type is "Builtin"
                        "Shadowing built-in identifier \"#{name}\""
                    else
                        "Shadowing identifier \"#{name}\" (first defined on
                         line #{written[0].first_line + 1})"
                })

        @scope[name] = {
            type: "Argument"
            read: false
            written: [node.locationData]
        }

    visitAssignment: (destination, source, shadow = false) =>
        # handles a (potentially destructured) assignment; currently called by:
        # * visitAssign
        # * visitFor
        # * visitParam
        # * visitTry
        @newState false, [], =>
            # create empty definition list and visit the target to populate
            if destination.constructor.name is "Literal"
                # work around coffeescript not producing Value nodes for all
                # types of assignments (simple ones that are part of bigger
                # statements are just stored as Literal nodes)
                @definitions.push([destination, destination.value])
            else
                @visit(destination)

            # visit source node before committing assignments
            @reading = true
            if source?
                @visit(source)

            # for all variables defined in this (potentially destructured)
            # assignment, find a variable matching that name in the nearest
            # scope and overwrite it, or create a new variable in the current
            # scope if no matches are found
            for [node, name] in @definitions
                if shadow
                    @identifierShadowed(node, name)
                else
                    @identifierAssigned(node, name)

    visitAssign: (node) =>
        @visitAssignment(node.variable, node.value)

    visitBlock: (node) =>
        if @depth isnt 1
            return node.eachChild(@visit)

        # start of root block; create global scope
        @newScope =>
            globals = normalize(@options["environments"], @options["globals"])
            for name of globals
                @scope[name] = {
                    type: "Builtin"
                    written: [node.locationData]
                }
            node.eachChild(@visit)

    visitClass: (node) =>
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
        @newScope true, =>
            if @definitions?
                for [node_, name] in @definitions
                    @scope[name] = {
                        type: "Variable"
                        read: false
                        written: [node_.locationData]
                    }

            @newState true, null, =>
                if node.parent?
                    @visit(node.parent)
                @visit(node.body)

    visitCode: (node) =>
        # if a function is defined as part of an assignment statement, a faux
        # scope is created that contains all the current assignments to allow
        # for recursive references
        @newScope true, =>
            if @definitions?
                for [node_, name] in @definitions
                    @scope[name] = {
                        type: "Variable"
                        read: false
                        written: [node_.locationData]
                    }

            @newScope =>
                @scope["arguments"] = {
                    type: "Builtin"
                    written: [node.locationData]
                }

                # visit the code as if not part of an assignment
                @newState true, null, =>
                    node.eachChild(@visit)

    visitFor: (node) =>
        if node.name?
            @visitAssignment(node.name)
        if node.index?
            @visitAssignment(node.index)
        node.eachChild(@visit)

    visitObj: (node) =>
        # object property names may be literals but are always interpreted as
        # string expressions (can't be assigned to)
        for prop in node.properties
            if prop.constructor.name is "Assign"
                @visit(prop.value)
            else
                @visit(prop)

    visitParam: (node) =>
        @visitAssignment(node.name, node.value, true)

    visitTry: (node) =>
        @visit(node.attempt)
        if node.errorVariable?
            @visitAssignment(node.errorVariable)
        if node.recovery?
            @visit(node.recovery)
        if node.ensure?
            @visit(node.ensure)

    visitValue: (node) =>
        if node.base.constructor.name isnt "Literal"
            # complex object (Arr or Obj)
            node.eachChild(@visit)
        else if node.isAssignable()
            # is an identifier and not a constant...
            name = node.base.value
            if node.hasProperties()
                # ... but may have been accesed as an array
                for prop in node.properties
                    if prop.constructor.name is "Index"
                        @newState true, null, =>
                            @visit(prop)

            if @reading or node.hasProperties()
                # an attempt (either direct or via a property or index) was
                # made to read a variable; this may result in an undefined
                # identifier error
                @identifierAccessed(node, name)
            else
                # this results in either an overwrite or the shadowing of an
                # existing variable from an outer scope; both use def lists
                @definitions.push([node, name])

    visit: (node) =>
        @depth++
        handler = this["visit#{node.constructor.name}"]
        if handler?
            # assume the handler will visit its children
            handler(node)
        else
            # walk through all child nodes
            node.eachChild(@visit)
        @depth--


defaultLinter = new ScopeLinter()
