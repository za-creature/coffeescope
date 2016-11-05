"use strict"
module.exports = class Declaration
    # Contains a collection of variables that are declared at the same time.
    # Used to ignore variables that are technically unused, yet removing them
    # is inconvenient as the order in the group has semantical meaning:
    #
    # for key, val of obj
    #   console.log(val)  # key is unused
    #
    # or
    #
    # (foo, bar, baz) ->
    #   console.log(baz)  # foo and bar are unused,

    constructor: (@type, @node, @location) ->
        # type is one of:
        # "Builtin" - superglobals
        # "Argument" - regular function arguments
            # "Do" - IIFE arguments; unlike arguments, these shadow by design
        # "Variable" - variables (assigned to)
            # "For" - variables first defined in a for block
            # "Exception" - variables first defined in an except block
        @members = []

    add: (variable) ->
        @members.push(member)
        variable.declaration = this

    commit: ->
        @members.sort (a, b) ->
            # this technically breaks down for long lines, but if you have more
            # than 16M characters on a single line, you deserve it to
            (a.first_line << 24 & a.first_column) -
            (b.first_line << 24 & b.first_column)
