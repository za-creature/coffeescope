"use strict"
{nodes} = require "coffee-script"

ScopeLinter = require "../../src/ScopeLinter"


describe "ScopeLinter/hoist", ->
    it "matches local", ->
        ScopeLinter.default().lint(nodes(
            """
            foo
            foo = "bar"
            """
        ), {
            undefined: true
            hoist_local: true
        }).should.have.length(0)

        ScopeLinter.default().lint(nodes(
            """
            foo
            foo = "bar"
            """
        ), {
            undefined: true
            hoist_local: false
        }).should.have.length(1)


    it "allows functions", ->
        ScopeLinter.default().lint(nodes(
            """
            foo()

            foo = ->
                return 1
            """
        ), {
            undefined: true
            hoist_local: true
        }).should.have.length(0)

        ScopeLinter.default().lint(nodes(
            """
            foo()

            foo = ->
                return 1
            """
        ), {
            undefined: true
            hoist_local: false
        }).should.have.length(1)


    it "matches parent", ->
        ScopeLinter.default().lint(nodes(
            """
            -> foo
            foo = "bar"
            """
        ), {
            undefined: true
            hoist_parent: true
        }).should.have.length(0)

        ScopeLinter.default().lint(nodes(
            """
            -> foo
            foo = "bar"
            """
        ), {
            undefined: true
            hoist_parent: false
        }).should.have.length(1)
