"use strict"
{nodes} = require "coffee-script"

ScopeLinter = require "../../src/ScopeLinter"


describe "ScopeLinter", ->
    it "forwards exceptions", ->
        err = new Error("foo")

        class FaultyScopeLinter extends ScopeLinter
            visit: ->
                throw err

        linter = new FaultyScopeLinter()
        (-> linter.lint(nodes(
            """
            hello world
            """
        ))).should.throw(err)
