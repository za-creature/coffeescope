"use strict"


module.exports = class Scope
    constructor: (@parent, options = {}) ->
        @symbols = Object.create(null)
        @options = {}
        for own key, value of options
            @options[key] = value

    local: (name, type = null) =>
        if not @symbols[name]
            @symbols[name] = {
                reads: []
                writes: []
                innerReads: []  # reads from inner scope
                innerWrites: []  # writes from inner scope
                type
            }
        @symbols[name]

    identifierRead: (name, node) =>
        @local(name).reads.push(node)
        undefined

    identifierWritten: (name, node, type) =>
        ref = @local(name)
        ref.writes.push(node)
        if not ref.type?
            ref.type = type
        undefined

    getScopeOf: (name) =>
        # only safe to call after this node has been committed
        if @symbols[name]? and @symbols[name].writes isnt 0
            this
        else
            @parent.getScopeOf(name)

    commit: =>
        for name, {reads, writes, type} of @symbols
            if type is "Argument"
                # variable is explicitly marked as local; keep it here
                continue

            scope = @parent.getScopeOf(name)
            if not scope?
                # no matching variable found in parent scope(s)
                continue

            {type, innerReads, innerWrites} = scope.symbols[name]
            if type is "Builtin" and writes.length
                # coffeescript treats builtins as undefined variables because
                # it doesn't know about `globals` and `environments`; reading
                # one is fine, but writing to one will create a local variable
                continue

            # if all the above rules fail, then this variable doesn't belong in
            # the current scope so we merge its usage into its parent
            Array::push.apply(innerReads, reads)
            Array::push.apply(innerWrites, writes)
            delete @symbols[name]
        undefined

    appendErrors: (errors) =>
        for name, {reads, writes, type, innerReads, innerWrites} of @symbols
            if not writes.length
                if @options["undefined"] then do ->
                    # issue an undefined variable error for every attempt to
                    # read it in the current scope; since this variable was
                    # never written in this scope, @getScopeOf will skip it so
                    # there's no need to look in inner scopes as they will have
                    # their own copy local copy
                    for {locationData} in reads
                        errors.push({
                            lineNumber: locationData.first_line + 1
                            message: "Undefined identifier \"#{name}\""
                        })

                # this is an undefined variable so all the other rules are
                # irelevant
                continue

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
                        message: "#{type} \"#{name}\" used before
                                  it was first defined (on line
                                  #{defined.first_line + 1}, column
                                  #{defined.first_column + 1})"})

            if not @options["hoist_local"]
                checkUsedBeforeDefined(reads)

            if not @options["hoist_parent"]
                checkUsedBeforeDefined(innerReads)

            if @options["shadow"] then do (type, writes) =>
                if type is "Builtin"
                    return  # local builtins always shadow by design

                parent = @parent.getScopeOf(name)
                if not parent?
                    return  # variable is not shadowing anything

                {type, writes} = parent.symbols[name]
                if type is "Builtin" and not @options["shadow_builtins"]
                    return  # user doesn't want to be notified about this

                for exception in @options["shadow_exceptions"] or []
                    if (new RegExp("^#{exception}$")).test(name)
                        return  # variable is allowed to shadow

                errors.push({
                    lineNumber: defined.first_line + 1
                    message: if type is "Builtin"
                        "Shadowing built-in identifier \"#{name}\""
                    else
                        "Shadowing #{type} \"#{name}\" (first defined on
                         line #{writes[0].locationData.first_line + 1})"
                })

            if @options["unused_#{type.toLowerCase()}s"] then do ->
                if reads.length or innerReads.length
                    return  # variable was used at least once

                for {locationData}, index in writes.concat(innerWrites)
                    # issue a variable-is-assigned-but-never-used warning every
                    # time it is accessed (here and in all child scopes)
                    errors.push({
                        # context: location
                        lineNumber: locationData.first_line + 1
                        message: if index
                            "#{type} \"#{name}\" is never used (first
                             defined on line #{defined.first_line + 1})"
                        else
                            "#{type} \"#{name}\" is never used"
                    })

            if @options["overwrite"] then do =>
                checkOverwrite = (nodes) ->
                    for {locationData} in nodes
                        errors.push({
                            # context: node.locationData
                            lineNumber: locationData.first_line + 1
                            message: "Overwriting #{type} \"#{name}\" (first
                                      defined on line #{defined.first_line +
                                      1})"
                        })

                if @options["same_scope"]
                    checkOverwrite(writes.slice(1))
                checkOverwrite(innerWrites)
        undefined
