"use strict"
{nodes} = require "coffee-script"

ScopeLinter = require "../../src/ScopeLinter"


describe "ScopeLinter/unused", ->
    it "matches trivial cases", ->
        ScopeLinter.default().lint(nodes(
            """
            foo = "bar"
            {bar} = "bar"
            """
        ), {
            unused_variables: true
        }).should.have.length(2)

        ScopeLinter.default().lint(nodes(
            """
            (foo) ->
                undefined

            ({foo}) ->
                undefined

            ({foo} = {foo: bar}) ->
                undefined
            """
        ), {
            unused_arguments: true
        }).should.have.length(3)


    it "matches classes", ->
        ScopeLinter.default().lint(nodes(
            """
            class Foo
            """
        ), {
            unused_variables: true
        }).should.have.length(1)

        ScopeLinter.default().lint(nodes(
            """
            class Foo

            class Bar extends Foo
            """
        ), {
            unused_variables: true
        }).should.have.length(1)


    it "matches for loops", ->
        ScopeLinter.default().lint(nodes(
            """
            for i in [1,2,3,4]
                undefined

            for i, index in [1,2,3,4]
                undefined

            for i in [0..4]
                undefined

            for i of {foo: "bar"}
                undefined

            for i, index of {foo: "bar"}
                undefined
            """
        ), {
            unused_variables: true
        }).should.have.length(7)


    it "issues multiple errors for the same value", ->
        ScopeLinter.default().lint(nodes(
            """
            foo = "bar"
            {foo} = "bar"
            """
        ), {
            unused_variables: true
        }).should.have.length(2)


    it "ignores object literals", ->
        ScopeLinter.default().lint(nodes(
            """
            {bar: "baz"}
            """
        ), {
            unused_arguments: true
            unused_variables: true
        }).should.have.length(0)


    it "matches indirect access", ->
        ScopeLinter.default().lint(nodes(
            """
            foo = {}
            foo[bar]
            foo.bar
            foo[0]
            foo.bar()
            """
        ), {
            unused_variables: true
        }).should.have.length(0)


    it "ignores builtins", ->
        ScopeLinter.default().lint(nodes(
            """
            foo = ->
                undefined
            foo()
            """
        ), {
            unused_arguments: true
            unused_variables: true
        }).should.have.length(0)


    it "ignores arguments when instructed", ->
        ScopeLinter.default().lint(nodes(
            """
            (foo) ->
                undefined
            """
        ), {
            unused_arguments: true
        }).should.have.length(1)

        ScopeLinter.default().lint(nodes(
            """
            (foo) ->
                undefined
            """
        ), {
            unused_arguments: false
        }).should.have.length(0)
