"use strict"
{nodes} = require "coffee-script"

ScopeLinter = require "../../src/ScopeLinter"


describe "ScopeLinter", ->
    it "forwards exceptions", ->
        class FaultyScopeLinter extends ScopeLinter
            err = new Error("foo")
            walk: ->
                throw err
            linter = new FaultyScopeLinter()
            (-> linter.lint(nodes(
                """
                hello world
                """
            ))).should.throw(err)
