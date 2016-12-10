"use strict"
lint = require "../helper"


describe "ScopeLinter/unused", ->
    defaults = {
        unused: "error"
        unused_variables: false
        unused_arguments: false
    }


    it "matches trivial cases", ->
        lint("""
            foo = "bar"
            {bar} = "bar"
        """, defaults)
        .total(2)
        .unused("foo")
        .unused("bar")

        lint("""
            (foo) ->
                undefined

            ({foo}) ->
                undefined

            ({foo} = {foo: bar}) ->
                undefined
        """, defaults)
        .total(3)
        .unused("foo", count: 3)


    it "matches classes", ->
        lint("""
            class Foo
        """, defaults)
        .total(1)
        .unused("Foo")

        lint("""
            class Foo

            class Bar extends Foo
        """, defaults)
        .total(1)
        .unused("Bar")


    it "supports classes as properties", ->
        lint("""
            PROP = "Bar"
            obj = {}

            class obj.Foo
            class obj[PROP]
        """, defaults)
        .total(0)


    it "ignores assigned classes", ->
        lint("""
            Bar = class Foo

            Bar
        """, defaults)
        .total(0)

        lint("""
            class Foo

            Baz = class Bar extends Foo

            Baz
        """, defaults)
        .total(0)


    it "matches recursive assignments", ->
        lint("""
            intervalId = setInterval ->
              clearInterval intervalId
            , 50
        """, defaults)
        .total(0)


    it "doesn't match named classes that are part of an assignment", ->
        lint("""
            Bar = class Foo
            Bar
        """, defaults)
        .total(0)


    it "matches for loops", ->
        lint("""
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
        """, defaults)
        .total(7)
        .unused("i", count: 5)
        .unused("index", count: 2)


    it "matches exceptions", ->
        lint("""
            try
                undefined
            catch err
                undefined
        """, defaults)
        .total(1)
        .unused("err")

        lint("""
            try
                undefined
            catch err
                console.log(err)
        """, defaults)
        .total(0)


    it "issues multiple errors for the same value", ->
        lint("""
            foo = "bar"
            {foo} = "bar"
        """, defaults)
        .total(2)
        .unused("foo", count: 2)


    it "ignores object literals", ->
        lint("""
            {bar: "baz"}
        """, defaults)
        .total(0)


    it "matches indirect access", ->
        lint("""
            foo = {}
            foo[bar]
            foo.bar
            foo[0]
            foo.bar()
        """, defaults)
        .total(0)


    it "ignores builtins", ->
        lint("""
            foo = ->
                undefined
            foo()
        """, defaults)
        .total(0)


    it "ignores arguments when instructed", ->
        lint("""
            (foo) ->
                undefined
        """, defaults)
        .total(1)
        .unused("foo")

        lint("""
            (foo) ->
                undefined
        """, defaults, unused_arguments: false)
        .total(0)


    it "supports special symbol names", ->
        lint("""
            constructor = 123
        """, defaults)
        .total(1)
        .unused("constructor")


    it "matches destructured defaults", ->
        lint("""
            defaultVal = 0
            { property = defaultVal } = {}
            property
        """, defaults)
        .total(0)


    it "matches nested destructured expressions", ->
        lint("""
            { property: nested: val } = { property: nested: 1 }
            val
        """, defaults)
        .total(0)


    it "matches do statements", ->
        lint("""
            for v, k in {foo: "bar"}
                do (v, k) ->
                    console.log(v, k)
        """, defaults)
        .total(0)

        lint("""
            afn = (fn) -> fn()

            do afn ->
              null
        """, defaults)
        .total(0)


    it "matches ranges", ->
        lint("""
            MAX_LENGTH = 3
            str = 'foobar'
            console.log str[...MAX_LENGTH]
        """, defaults)
        .total(0)
