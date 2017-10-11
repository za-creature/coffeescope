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

        # a list of functions that should be called in a separate sub-scope as
        # soon as the current scope is completely visited;
        # initialized, called and cleared by `newScope`
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
            global = new Scope(builtin, @options)
            @newScope global, =>
                @visit(root)
            @errors.sort((a, b) -> a.lineNumber - b.lineNumber)
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

            for fn in @subscopes
                @newScope(new Scope(@scope, @options), fn)

            @scope.appendErrors(@errors)
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

    visitAssignment: (destination, {source, shadow, comprehension} = {}) =>
        # handles a (potentially destructured) assignment; currently called by:
        # * visitAssign
        # * visitFor
        # * visitParam
        # * visitTry
        @newState false, [], =>
            # create empty definition list and visit the target to populate
            if destination.constructor.name in ["Literal", "IdentifierLiteral"]
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
            type = "Variable"
            if shadow
                type = "Argument"
            else if comprehension
                type = "Comprehension variable"
            for [name, node] in @definitions
                @scope.identifierWritten(name, node, type)
        undefined

    visitAssign: (node) =>
        @visitAssignment(node.variable, {source: node.value})
        undefined

    visitCall: (node) =>
        if node.do
            if node.variable.constructor.name is "Code"
                # call that is part of a `do` statement
                # don't want to shadow in this context
                @visitCode(node.variable, true)
            else
                @visit(node.variable)

            for arg in node.args or []
                if arg.name?
                    @scope.identifierRead(arg.name.value, arg)
                else
                    @visit(arg)

        else
            node.eachChild(@visit)
        undefined

    visitClass: (node) =>
        # a named class produces a variable in the local scope and in this
        # regard acts like an assignment statement
        if node.variable? and node.variable.isAssignable()
            if node.variable.shouldCache()
                # composite class definition; treat as a read for base value
                @visit(node.variable)
            else
                # regular named class definition
                @scope.identifierWritten(node.variable.base.value,
                                         node,
                                         "Class")
                if @definitions?
                    # allow named classes that are part of assignment
                    # statements without requiring their names to be read
                    @scope.identifierRead(node.variable.base.value,
                                          node.variable)

        if node.parent?
            @visit(node.parent)
        @subscopes.push =>
            @visit(node.body)
        undefined

    visitCode: (node, noShadow = false) =>
        @subscopes.push =>
            @scope.identifierWritten("arguments", node, "Builtin")
            if noShadow
                @scope.options["shadow"] = false

            for param in node.params or []
                @visit(param)
            @visit(node.body)
        undefined

    visitFor: (node) =>
        # because comprehensions compile to the same AST as regular for blocks
        # we distinguish between the two by checking bounds: a comprehension's
        # body has the same location as the node itself, whereas for a regular
        # for, the body is contained within the for block
        comprehension = true
        for prop in ["first_line", "first_column", "last_line", "last_column"]
            if node.locationData[prop] isnt node.body.locationData[prop]
                comprehension = false
                break

        if node.name?
            @visitAssignment(node.name, {comprehension})
        if node.index?
            @visitAssignment(node.index, {comprehension})
        node.eachChild(@visit)
        undefined

    visitObj: (node) =>
        # object property names may be literals but are interpreted as string
        # expressions unless when part of a destructured statement
        for prop in node.properties
            if prop.constructor.name is "Assign"
                if \
                        @reading or \
                        prop.context is "object"
                    @visit(prop.variable)
                    @visit(prop.value)
                else
                    @visitAssignment(prop.variable, {source: prop.value})
            else
                @visit(prop)
        undefined

    visitOp: (node) =>
        # unary ops ++ and -- should perform both a read and a write
        if node.operator in ["++", "--"]
            @visitAssignment(node.first)
            @visit(node.first)
        else
            node.eachChild(@visit)

    visitParam: (node) =>
        @visitAssignment(node.name, {source: node.value, shadow: true})
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
        if node.base.constructor.name in [
            "Literal", "ThisLiteral", "IdentifierLiteral"
        ]
            # simple (single-valued) object ...

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
                @newState true, null, =>
                    for prop in node.properties
                        if prop.constructor.name isnt "Access"
                            @visit(prop)
        else if node.base.constructor.name is "Call"
            # handles complex assignments like foo(bar).baz = qux
            @newState true, null, =>
                node.eachChild(@visit)
        else
            # complex object potentially containing more values (Arr or Obj)
            node.eachChild(@visit)
        undefined

    visitExportNamedDeclaration: (node) =>
        if node.clause.specifiers
            for specifier in node.clause.specifiers
                @scope.identifierRead(specifier.original.value, specifier)
        else
            switch node.clause.constructor.name
                when 'Assign'
                    @scope.identifierRead(node.clause.variable.value,
                                          node.clause.value)
                when 'Class'
                    @scope.identifierRead(node.clause.variable.base.value,
                                          node.clause.variable)
        node.eachChild(@visit)
        undefined


defaultLinter = new ScopeLinter()
