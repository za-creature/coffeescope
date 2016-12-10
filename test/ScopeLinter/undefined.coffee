"use strict"
lint = require "../helper"


describe "ScopeLinter/undefined", ->
    defaults = {
        undefined: "error"
        undefined_hoist: false
    }


    it "matches trivial cases", ->
        lint("""
            foo
            foo.bar
            foo[0]
            foo["bar"]
        """, defaults)
        .total(4)
        .undefined("foo", count: 4)

        lint("""
            foo = bar
        """, defaults)
        .total(1)
        .undefined("bar")

        lint("""
            foo = "bar"
        """, defaults)
        .total(0)


    it "matches unary operators", ->
        lint("""
            !foo
        """, defaults)
        .total(1)
        .undefined("foo")

        lint("""
            foo--
        """, defaults)
        .total(1)
        .undefined("foo")

        lint("""
            ++foo
        """, defaults)
        .total(1)
        .undefined("foo")


    it "creates subscope on no-assign", ->
        lint("""
            -> foo = "bar"
            foo
        """, defaults)
        .total(1)
        .undefined("foo")


    it "follows calls", ->
        lint("""
            foo(bar).type = "baz"
        """, defaults, globals: "foo")
        .total(1)
        .undefined("bar")


    it "allows recursion", ->
        lint("""
            foo = ->
                foo()
        """, defaults)
        .total(0)


    it "ignores object literals", ->
        lint("""
            foo = {bar: "baz"}
        """, defaults)
        .total(0)


    it "matches destructured object defaults", ->
        lint("""
            {foo = bar} = {}
        """, defaults)
        .total(1)
        .undefined("bar")


    it "ignores regular expressions", ->
        lint("""
            /foo/
            /foo/i
            /foo/i.exec
        """, defaults)
        .total(0)


    it "matches implicit object literals", ->
        lint("""
            foo = {bar: "baz", qux}
        """, defaults)
        .total(1)
        .undefined("qux")


    it "matches indexed access", ->
        lint("""
            foo = {}
            foo[bar]
        """, defaults)
        .total(1)
        .undefined("bar")


    it "ignores attribute access", ->
        lint("""
            foo = {}
            foo.bar
            foo["bar"]
        """, defaults)
        .total(0)


    it "converts indirect access to read", ->
        lint("""
            bar = "baz"
            foo.foo = "bar1"
            foo["foo"] = "bar2"
            foo[bar] = "bar3"
            foo[0] = "bar4"
            foo.foo
            foo["foo"]
            foo[bar]
            foo[0]
        """, defaults)
        .total(8)
        .undefined("foo", count: 8)


    it "follows indirect access", ->
        lint("""
            foo = "bar"
            foo[bar]
            foo.bar[baz]
            foo[bar].baz
        """, defaults)
        .total(3)
        .undefined("bar", count: 2)
        .undefined("baz")


    it "respects builtins", ->
        lint("""
            this

            ->
                arguments
        """, defaults)
        .total(0)


        lint("""
            console.log(process)
        """, defaults, environments: ["node"])
        .total(0)


    it "matches comprehensions", ->
        lint("""
            (y for x in [1,2,3])
        """, defaults)
        .total(1)
        .undefined("y")

        # see #16
        lint("""
            (x for x in [1..x])
        """, defaults)
        .total(0)


    it "matches destructured arguments", ->
        lint("""
            ({property}) -> property
        """, defaults)
        .total(0)

        lint("""
            ({property = false}) -> property
        """, defaults)
        .total(0)

        lint("""
            ({property = {}}) -> property
        """, defaults)
        .total(0)

        lint("""
            ({property: nested: foo}) -> foo
        """, defaults)
        .total(0)

        lint("""
            ({property = foo}) -> property
        """, defaults)
        .total(1)
        .undefined("foo")


    it "matches `do` function defaults", ->
        lint("""
            myVar2 = 2

            do (myVar = myVar2) ->
              myVar
        """, defaults, unused: "error")
        .total(0)
