"use strict"
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
        spawn("es6").should.have.property("Promise")


    it "accepts single-value arrays", ->
        spawn(["es6"]).should.have.property("Promise")


    it "merges multiple environments", ->
        result = spawn(["es6", "commonjs"])

        result.should.have.property("Promise")
        result.should.have.property("exports")


    it "ignores invalid / unknown environments", ->
        spawn("foo").should.have.property("this")
        spawn(["foo", "bar"]).should.have.property("this")
        spawn(["baz", "es6"]).should.have.property("Promise")
        spawn(["foo"], {"bar": true}).should.have.property("bar")


    it "treats `custom` as a regular environment", ->
        spawn([], )
        spawn("worker").should.have.property("self")
        spawn(["serviceworker", "worker"]).should.have.property("self")


    it "always includes`this`", ->
        spawn().should.have.property("this")
        spawn("es3").should.have.property("this")
        spawn(["es5", "es6"]).should.have.property("this")
