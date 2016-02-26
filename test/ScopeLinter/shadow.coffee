"use strict"
{nodes} = require "coffee-script"

ScopeLinter = require "../../src/ScopeLinter"


describe "ScopeLinter/shadow", ->
    it "matches trivial cases", ->
        ScopeLinter.default().lint(nodes(
            """
            foo = "bar"
            (foo) ->
                undefined
            """
        ), {
            shadow: true
        }).should.have.length(1)


    it "ignores object literals", ->
        ScopeLinter.default().lint(nodes(
            """
            foo = "bar"
            -> (bar = {foo: "bar2"})
            -> ({baz} = {"foo": "bar3"})
            """
        ), {
            shadow: true
        }).should.have.length(0)


    it "matches destructured assignments", ->
        ScopeLinter.default().lint(nodes(
            """
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
            """
        ), {
            shadow: true
        }).should.have.length(6)


    it "allows exceptions when instructed", ->
        ScopeLinter.default().lint(nodes(
            """
            foo = "bar"
            (foo) ->
                undefined
            """
        ), {
            shadow: true
            shadow_exceptions: ["foo"]
        }).should.have.length(0)


    it "matches multi-scope overwrites", ->
        ScopeLinter.default().lint(nodes(
            """
            foo = "bar"
            (foo) ->
                (foo) ->
                    undefined
                undefined
            """
        ), {
            shadow: true
        }).should.have.length(2)


    it "matches classes and functions", ->
        ScopeLinter.default().lint(nodes(
            """
            cb = null
            class cls

            foo = (
                cb = ->,
                cls = "foo"
            ) ->
                undefined
            """
        ), {
            shadow: true
        }).should.have.length(2)


    it "respects builtins when instructed", ->
        ScopeLinter.default().lint(nodes(
            """
            (exports) -> "foo"

            (module) -> "foo"
            """
        ), {
            environments: ["commonjs"]
            shadow: true
        }).should.have.length(0)


        ScopeLinter.default().lint(nodes(
            """
            (exports) -> "foo"

            (module) -> "foo"
            """
        ), {
            environments: ["commonjs"]
            shadow: true
            shadow_builtins: true
        }).should.have.length(2)


    it "matches assignments to builtins when instructed", ->
        ScopeLinter.default().lint(nodes(
            """
            exports = "foo"
            """
        ), {
            environments: ["commonjs"]
            shadow: true
        }).should.have.length(0)

        ScopeLinter.default().lint(nodes(
            """
            module = "foo"
            """
        ), {
            environments: ["commonjs"]
            shadow: true
            shadow_builtins: true
        }).should.have.length(1)
