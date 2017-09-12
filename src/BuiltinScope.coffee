"use strict"
globals = require "globals"

# support Cakefile
globals.cake =
    task: false
    option: false
    invoke: false

Scope = require "./Scope"


module.exports = class BuiltinScope extends Scope
    constructor: (envs = [], custom = {}) ->
        super(null, null)

        # argument handling
        custom["this"] = false  # `this` is always read-only
        if typeof envs is "string"
            envs = [envs]
        envs = for env in envs
            globals[env]
        envs.push(custom)

        # populate builtin symbol table
        for env in envs
            for own name of env
                @local(name).type = "Builtin"
        undefined

    getScopeOf: (name) => if @symbols[name]? then this else null  # no parent
