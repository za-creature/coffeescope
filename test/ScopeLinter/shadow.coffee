"use strict"
lint = require "../helper"


describe.only "ScopeLinter/shadow", ->
    defaults = {
        shadow: "error"
        shadow_builtins: false
    }


    it "matches trivial cases", ->
        lint("""
            foo = "bar"
            (foo) ->
                undefined
        """, defaults)
        .total(1)
        .shadow("foo")


    it "ignores object literals", ->
        lint("""
            foo = "bar"
            -> (bar = {foo: "bar2"})
            -> ({baz} = {"foo": "bar3"})
        """, defaults)
        .total(0)


    it "allows do statements", ->
        lint("""
            foo = bar = "baz"
            do (foo, bar) ->
                undefined
        """, defaults)
        .total(0)


    it "matches destructured assignments", ->
        lint("""
            foo = "bar"
            (foo...) ->
                undefined
            ([foo]) ->
                undefined
            ([foo] = ["bar3"]) ->
                undefined
            ({foo}) ->
                undefined
            ({foo} = {foo: "bar"}) ->
                undefined
            ([{foo}, {baz}] = [{"foo": "bar4"}, {"baz": "bar5"}]) ->
                undefined
        """, defaults)
        .total(6)
        .shadow("foo", count: 6)


    it "allows exceptions when instructed", ->
        lint("""
            foo = "bar"
            (foo) ->
                undefined
        """, defaults, shadow_exceptions: ["foo"])
        .total(0)

        lint("""
            foo = "bar"
            (foo) ->
                undefined
        """, defaults, shadow_exceptions: ["f.."])
        .total(0)

        lint("""
            foo = "bar"
            (foo) ->
                undefined
        """, defaults, shadow_exceptions: ["bar"])
        .total(1)
        .shadow("foo")


    it "matches multi-scope overwrites", ->
        lint("""
            foo = "bar"
            (foo) ->
                (foo) ->
                    undefined
                undefined
        """, defaults)
        .total(2)
        .shadow("foo", count: 2)


    it "matches classes and functions", ->
        lint("""
            cb = null
            class cls

            foo = (
                cb = ->,
                cls = "foo"
            ) ->
                undefined
        """, defaults)
        .total(2)
        .shadow("cls")
        .shadow("cb")


    it "matches builtins", ->
        lint("""
            (exports) -> "foo"
            (module) -> "foo"
        """, defaults, environments: ["commonjs"])
        .total(2)
        .shadow("exports")
        .shadow("module")


    it.only "matches assigning to builtins", ->
        lint("""
            exports = "foo"
            module = "foo"
        """, defaults, environments: ["commonjs"])
        .total(2)
        .shadow("exports")
        .shadow("module")


    it "doesn't shadow arguments or this", ->
        lint("""
            foo = ->
                bar = ->
                    undefined
        """, defaults)
        .total(0)
