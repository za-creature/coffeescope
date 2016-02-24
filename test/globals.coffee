"use strict"
globals = require "../src/globals"


describe "globals", ->
    it "defaults to empty", ->
        Object.keys(globals()).length.should.equal(1)


    it "accepts single environments", ->
        globals("es6").should.have.property("Promise", false)


    it "accepts single-value arrays", ->
        globals(["es6"]).should.have.property("Promise", false)


    it "merges multiple environments", ->
        result = globals(["es6", "commonjs"])

        result.should.have.property("Promise", false)
        result.should.have.property("exports", true)


    it "allows writing if at least one environment allows it", ->
        globals("serviceworker").should.have.property("self", false)
        globals("worker").should.have.property("self", true)
        globals(["serviceworker", "worker"]).should.have.property("self", true)


    it "ignores invalid / unknown environments", ->
        globals("foo").should.have.property("this", false)
        globals(["foo", "bar"]).should.have.property("this", false)
        globals(["baz", "es6"]).should.have.property("Promise", false)
        globals(["foo"], {"bar": true}).should.have.property("bar", true)


    it "treats `custom` as a regular environment", ->
        globals([], )
        globals("worker").should.have.property("self", true)
        globals(["serviceworker", "worker"]).should.have.property("self", true)


    it "always includes read-only `this`", ->
        globals().should.have.property("this", false)
        globals("es3").should.have.property("this", false)
        globals(["es5", "es6"]).should.have.property("this", false)
        globals([], {"this": true}).should.have.property("this", false)
