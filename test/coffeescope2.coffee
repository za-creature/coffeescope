"use strict"
{expect} = require "chai"
proxyquire = require "proxyquire"


describe "coffeescope2", ->
    it "should be a coffeelint AST module", ->
        Coffeescope2 = require "../src"
        Coffeescope2.should.be.an.instanceof(Function)
        Coffeescope2::rule.should.have.property("name", "check_scope")
        Coffeescope2::rule.should.have.property("description")
        Coffeescope2::rule.should.have.property("message")
        Coffeescope2::should.have.property("lintAST")


    it "should default to warn", ->
        Coffeescope2 = require "../src"
        Coffeescope2::rule.should.have.property("level", "warn")


    it "should forward the root and only the relevant config", ->
        calledWith = null
        Coffeescope2 = proxyquire "../src",
            "./ScopeLinter":
                default: ->
                    lint: ->
                        calledWith = arguments

        cs2 = new Coffeescope2()

        cs2.errors = []
        cs2.lintAST("foo", {
            config: {
                bar: "baz"
                check_scope: {
                    hello: "world"
                }
            }
            createError: (e) -> e
        })
        expect(calledWith).to.exist
        calledWith[0].should.equal("foo")
        calledWith[1].should.have.property("hello", "world")


    it "converts and stores all errors", ->
        Coffeescope2 = proxyquire "../src",
            "./ScopeLinter":
                default: ->
                    lint: -> ["foo", "bar", "baz"]

        converted = 0
        cs2 = new Coffeescope2()

        cs2.errors = []
        result = cs2.lintAST("foo", {
            config: {
                bar: "baz"
                check_scope: {
                    hello: "world"
                }
            }
            createError: (e) ->
                converted += 1
                return "conv" + e
        })
        expect(result).to.not.exist
        converted.should.equal(3)
        cs2.errors.should.have.length(3)
        cs2.errors.should.contain("convfoo")
        cs2.errors.should.contain("convbar")
        cs2.errors.should.contain("convbaz")
