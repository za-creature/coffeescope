"use strict"
{expect} = require "chai"

BuiltinScope = require "../src/BuiltinScope"


describe "BuiltinScope", ->
    spawn = ->
        args = [null]
        Array::push.apply(args, arguments)
        instance = new (Function::bind.apply(BuiltinScope, args))
        return instance.symbols


    it "defaults to empty", ->
        Object.keys(spawn()).length.should.equal(1)


    it "accepts single environments", ->
        expect(spawn("es2015")).to.have.property("Promise")


    it "accepts single-value arrays", ->
        expect(spawn(["es2015"])).to.have.property("Promise")


    it "merges multiple environments", ->
        result = spawn(["es2015", "commonjs"])

        expect(result).to.have.property("Promise")
        expect(result).to.have.property("exports")


    it "ignores invalid / unknown environments", ->
        expect(spawn("foo")).to.have.property("this")
        expect(spawn(["foo", "bar"])).to.have.property("this")
        expect(spawn(["baz", "es2015"])).to.have.property("Promise")
        expect(spawn(["foo"], {"bar": true})).to.have.property("bar")


    it "treats `custom` as a regular environment", ->
        spawn([], )
        expect(spawn("worker")).to.have.property("self")
        expect(spawn(["serviceworker", "worker"])).to.have.property("self")


    it "always includes `this`", ->
        expect(spawn()).to.have.property("this")
        expect(spawn("builtin")).to.have.property("this")
        expect(spawn(["es5", "es2015"])).to.have.property("this")
