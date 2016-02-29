"use strict"
BuiltinScope = require "./BuiltinScope"
Scope = require "./Scope"


module.exports = class ScopeLinter
    @default: -> defaultLinter  # initialized on the bottom of the file

    constructor: ->
        # the scope available in the current node; a new scope is pushed every
        # time a Code node is encountered and popped every time a Code node has
        # been completely visited.
        @scope = null

        # a list of functions (and classes) that should be evaluated in a
        # separate sub-scope; initialized, visited and cleared by `newScope`
        @subscopes = null

        # whether a Value node is expected to read an existing value, or create
        # a new variable (either by shadowing or overwriting)
        @reading = true

        # a list of variable definitions to insert in the current scope;
        # created whenever a (possibly destructured) assignment is encountered
        # the list of definitions is popped and merged into the current scope
        # every time an Assign node has been completely visited.
        @definitions = null

        undefined

    lint: (root, @options) =>
        @errors = []
        try
            builtin = new BuiltinScope(@options["environments"],
                                       @options["globals"])
            global = new Scope(builtin)
            @newScope global, =>
                @visit(root)
            return @errors
        finally
            delete @options
            delete @errors

    newState: (reading, definitions, cb) =>
        # invokes `cb()` in a new state defined by `reading` and `definitions`
        # and restores the previous state when cb exists
        old = [@reading, @definitions]
        [@reading, @definitions] = [reading, definitions]
        try
            cb()
            undefined
        finally
            [@reading, @definitions] = old

    newScope: (scope, cb) =>
        # invokes `cb` in `scope`
        old = [@scope, @subscopes]
        @scope = scope
        @subscopes = []

        try
            cb()
            @scope.commit()

            for node in @subscopes
                # create a new function scope
                fn = new Scope(@scope)
                fn.identifierWritten("arguments", node)
                fn.symbols["arguments"].type = "Builtin"

                @newScope fn, =>
                    if node.params?
                        for param in node.params
                            @visit(param)
                    @visit(node.body)

            @scope.appendErrors(@errors, @options)
            undefined
        finally
            [@scope, @subscopes] = old

    visit: (node) =>
        handler = this["visit#{node.constructor.name}"]
        if handler?
            # assume the handler will visit its children
            handler(node)
        else
            # walk through all child nodes
            node.eachChild(@visit)
        undefined

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
                @definitions.push([destination.value, destination])
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
            for [name, node] in @definitions
                @scope.identifierWritten(name, node, shadow)
        undefined

    visitAssign: (node) =>
        @visitAssignment(node.variable, node.value)
        undefined

    visitClass: (node) =>
        # a named class produces a variable in the local scope and in this
        # regard acts like an assignment statement
        if node.variable? and node.variable.base.isAssignable()
            @scope.identifierWritten(node.variable.base.value, node.variable)
            if @definitions?
                # allow named classes that are part of assignment statements
                # without requiring their names to be read
                @scope.identifierRead(node.variable.base.value,
                                      node.variable.base)

        if node.parent?
            @visit(node.parent)
        @subscopes.push(node)
        undefined

    visitCode: (node) =>
        @subscopes.push(node)
        undefined

    visitFor: (node) =>
        if node.name?
            @visitAssignment(node.name)
        if node.index?
            @visitAssignment(node.index)
        node.eachChild(@visit)
        undefined

    visitObj: (node) =>
        # object property names may be literals but are always interpreted as
        # string expressions (can't be assigned to)
        for prop in node.properties
            if prop.constructor.name is "Assign"
                @visit(prop.value)
            else
                @visit(prop)
        undefined

    visitParam: (node) =>
        @visitAssignment(node.name, node.value, true)
        undefined

    visitTry: (node) =>
        @visit(node.attempt)
        if node.errorVariable?
            @visitAssignment(node.errorVariable)
        if node.recovery?
            @visit(node.recovery)
        if node.ensure?
            @visit(node.ensure)
        undefined

    visitValue: (node) =>
        if node.base.constructor.name is "Literal"
            # simple object ...

            if node.base.isAssignable()
                # ... that is an identifier ...
                name = node.base.value
                if @reading or node.hasProperties()
                    # an attempt (either direct or via a property or index) was
                    # made to read a variable; this may result in an undefined
                    # identifier error
                    @scope.identifierRead(name, node)
                else
                    # this results in either an overwrite or the shadowing of a
                    # existing variable from an outer scope; both use def lists
                    @definitions.push([name, node])

            if node.hasProperties()
                # ... that may have been accesed as an array
                for prop in node.properties
                    if prop.constructor.name is "Index"
                        @newState true, null, =>
                            @visit(prop)
        else
            # complex object (Arr or Obj)
            node.eachChild(@visit)
        undefined


defaultLinter = new ScopeLinter()
