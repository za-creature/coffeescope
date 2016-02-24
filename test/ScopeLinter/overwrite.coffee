"use strict"
{nodes} = require "coffee-script"

ScopeLinter = require "../../src/ScopeLinter"


describe "ScopeLinter/overwrite", ->
    it "matches trivial cases", ->
        ScopeLinter.default().lint(nodes(
            """
            foo = "bar"
            foo = "bar2"
            """
        ), {
            overwrite: true
            same_scope: true
        }).should.have.length(1)


    it "matches classes", ->
        ScopeLinter.default().lint(nodes(
            """
            class Foo

            Foo = "bar2"
            """
        ), {
            overwrite: true
            same_scope: true
        }).should.have.length(1)

        ScopeLinter.default().lint(nodes(
            """
            Foo = "bar2"

            class Foo
            """
        ), {
            overwrite: true
            same_scope: true
        }).should.have.length(1)

        ScopeLinter.default().lint(nodes(
            """
            Foo = class Foo
            """
        ), {
            overwrite: true
            same_scope: true
        }).should.have.length(1)


        ScopeLinter.default().lint(nodes(
            """
            Foo = class
            """
        ), {
            overwrite: true
            same_scope: true
        }).should.have.length(0)


    it "matches for loops", ->
        ScopeLinter.default().lint(nodes(
            """
            i = 0
            index = 0

            ->
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
            overwrite: true
        }).should.have.length(7)


    it "matches functions", ->
        ScopeLinter.default().lint(nodes(
            """
            foo = ->
            """
        ), {
            overwrite: true
        }).should.have.length(0)

        ScopeLinter.default().lint(nodes(
            """
            foo = ->
                foo = null
            """
        ), {
            overwrite: true
        }).should.have.length(1)


    it "ignores methods", ->
        ScopeLinter.default().lint(nodes(
            """
            foo = "asd"

            class bar
                foo: ->
                    undefined
            """
        ), {
            overwrite: true
            same_scope: true
        }).should.have.length(0)


    it "ignores object literals", ->
        ScopeLinter.default().lint(nodes(
            """
            foo = "bar"
            {bar} = {foo: "bar2"}
            {baz} = {"foo": "bar3"}
            """
        ), {
            overwrite: true
            same_scope: true
        }).should.have.length(0)


    it "matches destructured assignments", ->
        ScopeLinter.default().lint(nodes(
            """
            foo = "bar"
            {foo} = {foo: "bar2"}
            [foo] = ["bar3"]
            [{foo}, {baz}] = [{"foo": "bar4"}, {"baz": "bar5"}]
            """
        ), {
            overwrite: true
            same_scope: true
        }).should.have.length(3)


    it "ignores same-scope overwrites when instructed", ->
        ScopeLinter.default().lint(nodes(
            """
            foo = "bar"
            foo = "bar2"
            """
        ), {
            overwrite: true
            same_scope: false
        }).should.have.length(0)


    it "always matches on out-of-scope overwrites", ->
        ScopeLinter.default().lint(nodes(
            """
            foo = "bar"
            -> foo = "bar2"
            """
        ), {
            overwrite: true
            same_scope: false
        }).should.have.length(1)


    it "ignores shadowed variables", ->
        ScopeLinter.default().lint(nodes(
            """
            foo = "bar"
            (foo) ->
                foo = "bar2"
                {foo} = {foo: "bar2"}
                [foo] = ["bar3"]
                [{foo}, {baz}] = [{foo: "bar4"}, {baz: "bar5"}]
            """
        ), {
            overwrite: true
        }).should.have.length(0)


    it "ignores indirect writes", ->
        ScopeLinter.default().lint(nodes(
            """
            foo = "bar"
            foo.foo = "bar1"
            foo["foo"] = "bar2"
            foo[foo] = "bar3"
            foo[0] = "bar4"
            """
        ), {
            overwrite: true
            same_scope: true
        }).should.have.length(0)


    it "ignores assignments to builtins", ->
        ScopeLinter.default().lint(nodes(
            """
            exports = "foo"
            module = "foo"
            """
        ), {
            environments: ["commonjs"]
            overwrite: true
        }).should.have.length(0)
