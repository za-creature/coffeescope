"use strict"
Variable = require "./variable"


module.exports = class Scope
    constructor: (@parent = null) ->
        if @parent?
            @parent.children.push(this)

        @children = []
        @reads = Object.create(null)
        @writes = Object.create(null)
        @symbols = Object.create(null)  # stores the symbol table for locals

    read: (name, node) =>
        if not @reads[name]?
            @reads[name] = []
        @reads[name].push(node)
        undefined

    write: (name, node, declaration) =>
        if not @writes[name]?
            @writes[name] = []
        @writes[name].push([node, declaration])
        undefined

    variable: (name) => @symbols[name] or @parent?.variable(name)

    errors: (options) =>
        results = []
        error = ({name, message, type, location}) ->
            level = options[type]
            for pattern in options["#{type}_except"] or []
                if name.match(new RegExp("^#{pattern}$"))
                    level = "ignore"
                    break

            results.push({
                symbol: name
                message
                code: type.toUpperCase()
                level
                location
                lineNumber: location.first_line + 1
            })

        # figure out what writes create new symbols in the current scope and
        # what writes overwrite values from parent scopes
        for name, writes of @writes
            local = null

            for args in writes
                [node, declaration] = args
                if declaration.type in ["Argument", "Do"]
                    # this variable was declared at least once as an argument;
                    # define a local at the first argument declaration
                    if local?
                        throw new Error("Must never happen")
                    local = args

            ref = @variable(name)
            if not ref? or ref.type is "Builtin"
                # coffeescript treats builtins as undefined variables because
                # it doesn't know about `globals` and `environments`; reading
                # one is fine, but writing to one will create a local variable
                local = writes[0]

            if local?
                # if this variable doesn't yet exist or must be local, add a
                # new entry to this scope's symbol table and ensure the next
                # operation happens on the local copy (in the event it's
                # shadowing a parent value)
                ref = @symbols[name] = new Variable(name, this, local...)

            # remember all attempts to write to this variable in this scope
            for node in writes
                ref.writes.push([this, node])

        # find attempts to read unidentified symbols and record the in-scope
        # reads of all existing symbols; hoisting is handled separately
        for name, reads of @reads
            ref = @variable(name)
            if ref?
                for node in reads
                    ref.reads.push([this, node])
            else
                # issue an undefined identifier error for every attempt to read
                # it in the current scope; since an entry is not stored in the
                # symbol table, subscopes that don't declare a local symbol of
                # the same name will see it as undefined as well
                for node in reads
                    error({
                        name,
                        message: "Undefined identifier \"#{name}\""
                        type: "undefined",
                        location: node.locationData
                    })

        for scope in @children
            for err in scope.errors(options)
                results.push(err)

        for name, ref of @symbols
            parent = @parent?.variable(name)
            if parent? and parent isnt ref
                # this variable is shadowing another (possibly builtin)
                # variable from a parent scope
                console.log(name, parent.declaration.type)
                if parent.declaration.type is "Builtin"
                    if options["shadow_builtins"] is false or (
                        options["shadow_builtins"] is "arguments" and \
                        ref.declaration.type not in ["Do", "Argument"]
                    )
                        error({
                            name,
                            message: "Shadowing built-in identifier
                                      \"#{name}\""
                            type: "shadow",
                            location: ref.location
                        })
                else if ref.declaration.type is "Argument"
                    error({
                        name,
                        message: "Shadowing identifier \"#{name}\" (first
                                  defined on line
                                  #{parent.location.first_line + 1}"
                        type: "shadow",
                        location: ref.location
                    })

            if not ref.reads.length and ref.declaration.type isnt "Builtin"
                # this non-builtin variable was never read in this scope or any
                # of the subscopes it was visible in; as such, it may be
                # removed without affecting the compiled code
                for write, index in ref.writes
                    error({
                        name,
                        message: "Identifier \"#{name}\" is assigned to but
                                  never read" + if index then " (first defined
                                  on line #{ref.location.first_line + 1})" \
                                  else ""
                        type: "unused"
                        location: ref.location
                    })

        ###

            defined = writes[0].locationData
            comprehension = @symbols[name].type is "Comprehension variable"

            checkUsedBeforeDefined = (nodes) ->
                # issue a used-before-undefined variable error for ever
                # attempt to read the current variable before it was defined
                isBefore = (a, b) -> a.first_line < b.first_line or (
                    a.first_line is b.first_line and
                    a.first_column <= b.first_column
                )

                for {locationData} in nodes
                    if comprehension or not isBefore(locationData, defined)
                        # comprehensions can't be reliably checked so we ignore
                        # them to avoid false positives (#16)
                        continue

                    errors.push({
                        lineNumber: locationData.first_line + 1
                        message: "#{type} \"#{name}\" used before it was first
                                  defined (on line #{defined.first_line + 1},
                                  column #{defined.first_column + 1})"})

            if not options["hoist_local"]
                checkUsedBeforeDefined(reads)

            if not options["hoist_parent"]
                checkUsedBeforeDefined(innerReads)

            if options["shadow"] then do (type, writes) =>
                if type is "Builtin"
                    return  # local builtins always shadow by design

                parent = @parent.getScopeOf(name)
                if not parent?
                    return  # variable is not shadowing anything

                {type, writes} = parent.symbols[name]
                if type is "Builtin" and not options["shadow_builtins"]
                    return  # user doesn't want to be notified about this

                for exception in options["shadow_exceptions"] or []
                    if (new RegExp("^#{exception}$")).test(name)
                        return  # variable is allowed to shadow

                errors.push({
                    lineNumber: defined.first_line + 1
                    message: if type is "Builtin"
                        "Shadowing built-in identifier \"#{name}\""
                    else
                        "Shadowing #{type.toLowerCase()} \"#{name}\" (first
                         defined on line
                         #{writes[0].locationData.first_line + 1})"
                })

            if \
                    (type in ["Comprehension variable",
                              "Variable",
                              "Exception"] and \
                    options["unused_variables"]) or \
                    type is "Class" and options["unused_classes"] or \
                    type is "Argument" and options["unused_arguments"]
            then do ->
                if reads.length or innerReads.length
                    return  # variable was read at least once

                for {locationData}, index in writes.concat(innerWrites)
                    # issue a variable-is-assigned-but-never-read warning every
                    # time it is accessed (here and in all child scopes)
                    errors.push({
                        # context: location
                        lineNumber: locationData.first_line + 1
                        message: if index
                            "#{type} \"#{name}\" is assigned to but never read
                             (first defined on line #{defined.first_line + 1})"
                        else
                            "#{type} \"#{name}\" is assigned to but never read"
                    })

            if options["overwrite"] then do =>
                checkOverwrite = (nodes) ->
                    for {locationData} in nodes
                        errors.push({
                            # context: node.locationData
                            lineNumber: locationData.first_line + 1
                            message: "Overwriting #{type.toLowerCase()}
                                      \"#{name}\" (first defined on line
                                      #{defined.first_line + 1})"
                        })

                if options["same_scope"]
                    checkOverwrite(writes.slice(1))
                checkOverwrite(innerWrites)###
        return results
