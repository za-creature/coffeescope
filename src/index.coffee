"use strict"
ScopeLinter = require "./ScopeLinter"


module.exports = class Coffeescope2
    rule:
        name: "check_scope"
        description: """
            This rule checks the usage of your variables and prevents common
            mistakes or enforces style conventions. It can find and report:

            * Attempting to access an undefined variables
            * Unused variables and arguments (i.e. variables that were assigned
              to but never read)
            * Variables that shadow other variables from an outer scope (due to
              the scoping rules in coffeescript, these can _only_ be arguments
              or builtins like `Math`)
            * Variables that overwrite other variables from an outer scope (due
              to the scoping rules in coffeescript, these can _never_ be
              arguments or builtins like `Math`)
        """
        level: "ignore"  # not actually used
        environments: ["builtin", "es5", "es6"]
        globals: []

        undefined: "error"
        undefined_hoist: "parent"

        unused: "warn"
        unused_arguments: false
        unused_except: ["_.*"]

        shadow: "warn"
        shadow_builtins: false
        shadow_except: ["_.*", "err", "next"]

        overwrite: "warn"
        overwrite_local: true
        overwrite_except: ["_.*"]

    lintAST: (root, {config, createError}) ->
        @errors = []
        for spec in ScopeLinter.default().lint(root, config[@rule.name])
            @errors.push(createError(spec))
        undefined


module.exports.ScopeLinter = ScopeLinter
