"use strict"
{nodes} = require "coffee-script"

ScopeLinter = require "../src/ScopeLinter"


class Helper
    constructor: (@errors) ->
        undefined

    debug: ->
        console.log(@errors)
        return this

    _count: ({code, level, symbol} = {}) ->
        result = 0
        for error in @errors when (
            (error.level isnt "ignore") and
            (not code? or error.code is code.toUpperCase()) and
            (not level? or error.level is level) and
            (not symbol? or error.symbol is symbol)
        )
            result++
        return result

    total: (expected) ->
        @_count().should.equal(expected)
        return this

    for code in ["undefined", "unused", "shadow", "overwrite"]
        do (code) ->
            Helper::[code] = (symbol, {level, count = 1} = {}) ->
                @_count({code, level, symbol}).should.equal(count)
                return this

    for level in ["warn", "error"]
        do (level) ->
            Helper::[level] = (symbol, {code, count = 1} = {}) ->
                @_count({code, level, symbol}).should.equal(count)
                return this


module.exports = (code, opts...) ->
    new Helper(
        ScopeLinter.default().lint(
            nodes(code),
            Object.assign({}, {
                environments: []
                globals: []
                undefined: "ignore"
                unused: "ignore"
                shadow: "ignore"
                overwrite: "ignore"
            }, opts...)
        )
    )
