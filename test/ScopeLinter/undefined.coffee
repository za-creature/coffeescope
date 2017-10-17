"use strict"
{nodes} = require "coffeescript"

ScopeLinter = require "../../src/ScopeLinter"


describe "ScopeLinter/undefined", ->
    it "matches trivial cases", ->
        ScopeLinter.default().lint(nodes(
            """
            foo
            foo.bar
            foo[0]
            foo["bar"]
            """
        ), {
            undefined: true
        }).should.have.length(4)

        ScopeLinter.default().lint(nodes(
            """
            foo = bar
            """
        ), {
            undefined: true
        }).should.have.length(1)

        ScopeLinter.default().lint(nodes(
            """
            foo = "bar"
            """
        ), {
            undefined: true
        }).should.have.length(0)


    it "matches unary operators", ->
        ScopeLinter.default().lint(nodes(
            """
            !foo
            """
        ), {
            undefined: true
        }).should.have.length(1)

        ScopeLinter.default().lint(nodes(
            """
            foo--
            """
        ), {
            undefined: true
        }).should.have.length(1)

        ScopeLinter.default().lint(nodes(
            """
            ++foo
            """
        ), {
            undefined: true
        }).should.have.length(1)


    it "creates subscope on no-assign", ->
        ScopeLinter.default().lint(nodes(
            """
            foo
            -> foo = "bar"
            """
        ), {
            undefined: true
        }).should.have.length(1)


    it "follows calls", ->
        ScopeLinter.default().lint(nodes(
            """
            foo(bar).type = "baz"
            """
        ), {
            undefined: true
            globals: {"foo": true}
        }).should.have.length(1)


    it "allows recursion", ->
        ScopeLinter.default().lint(nodes(
            """
            foo = ->
                foo()
            """
        ), {
            undefined: true
        }).should.have.length(0)


    it "ignores object literals", ->
        ScopeLinter.default().lint(nodes(
            """
            foo = {bar: "baz"}
            """
        ), {
            undefined: true
        }).should.have.length(0)


    it "matches destructured object defaults", ->
        ScopeLinter.default().lint(nodes(
            """
            {foo = bar} = {}
            """
        ), {
            undefined: true
        }).should.have.length(1)


    it "ignores regular expressions", ->
        ScopeLinter.default().lint(nodes(
            """
            /foo/
            /foo/i
            /foo/i.exec
            """
        ), {
            undefined: true
        }).should.have.length(0)


    it "matches implicit object literals", ->
        ScopeLinter.default().lint(nodes(
            """
            foo = {bar: "baz", bar}
            """
        ), {
            undefined: true
        }).should.have.length(1)


    it "matches indexed access", ->
        ScopeLinter.default().lint(nodes(
            """
            foo = {}
            foo[bar]
            """
        ), {
            undefined: true
        }).should.have.length(1)


    it "ignores attribute access", ->
        ScopeLinter.default().lint(nodes(
            """
            foo = {}
            foo.bar
            foo["bar"]
            """
        ), {
            undefined: true
        }).should.have.length(0)


    it "converts indirect access to read", ->
        ScopeLinter.default().lint(nodes(
            """
            bar = "baz"
            foo.foo = "bar1"
            foo["foo"] = "bar2"
            foo[bar] = "bar3"
            foo[0] = "bar4"
            foo.foo
            foo["foo"]
            foo[bar]
            foo[0]
            """
        ), {
            undefined: true
        }).should.have.length(8)


    it "follows indirect access", ->
        ScopeLinter.default().lint(nodes(
            """
            foo = "bar"
            foo[bar]
            foo.bar[baz]
            foo[bar].baz
            """
        ), {
            undefined: true
        }).should.have.length(3)


    it "respects builtins", ->
        ScopeLinter.default().lint(nodes(
            """
            this
            """
        ), {
            undefined: true
        }).should.have.length(0)


        ScopeLinter.default().lint(nodes(
            """
            ->
                arguments
            """
        ), {
            undefined: true
        }).should.have.length(0)


        ScopeLinter.default().lint(nodes(
            """
            console.log(process)
            """
        ), {
            environments: ["node"]
            undefined: true
        }).should.have.length(0)


    it "matches comprehensions", ->
        ScopeLinter.default().lint(nodes(
            """
            (y for x in [1,2,3])
            """
        ), {
            undefined: true
        }).should.have.length(1)

        # see #16
        ScopeLinter.default().lint(nodes(
            """
            (x for x in [1..x])
            """
        ), {
            undefined: true
        }).should.have.length(0)


    it "matches destructured arguments", ->
        ScopeLinter.default().lint(nodes(
            """
            ({property}) -> property
            """
        ), {
            undefined: true
        }).should.have.length(0)

        ScopeLinter.default().lint(nodes(
            """
            ({property = false}) -> property
            """
        ), {
            undefined: true
        }).should.have.length(0)

        ScopeLinter.default().lint(nodes(
            """
            ({property = {}}) -> property
            """
        ), {
            undefined: true
        }).should.have.length(0)

        ScopeLinter.default().lint(nodes(
            """
            ({property: foo}) -> foo
            """
        ), {
            undefined: true
        }).should.have.length(0)

        ScopeLinter.default().lint(nodes(
            """
            ({property = foo}) -> property
            """
        ), {
            undefined: true
        }).should.have.length(1)


    it "matches `do` function defaults", ->
        ScopeLinter.default().lint(nodes(
            """
            myVar2 = 2

            do (myVar = myVar2) ->
              myVar
            """
        ), {
            undefined: true,
            unused: true
        }).should.have.length(0)

    it "handles imports", ->
        ScopeLinter.default().lint(nodes(
            """
            import Foo from 'foo'
            Foo
            """
        ), {
            undefined: true
        }).should.have.length(0)

        ScopeLinter.default().lint(nodes(
            """
            import {Foo as Bar} from 'foo'
            Bar
            """
        ), {
            undefined: true
        }).should.have.length(0)

        ScopeLinter.default().lint(nodes(
            """
            import {Foo, Bar} from 'foo'
            Foo
            Bar
            """
        ), {
            undefined: true
        }).should.have.length(0)
