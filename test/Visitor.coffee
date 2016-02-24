"use strict"
{nodes} = require "coffee-script"

Visitor = require "../src/Visitor"


describe "Visitor", ->
    class TestVisitor extends Visitor
        constructor: (@returnValue) ->
            @enterArgs = []
            @exitArgs = []

        nodeEnter: (node) =>
            super(node)
            Array::push.apply(@enterArgs, arguments)
            return @returnValue

        nodeExit: (node) =>
            super(node)
            Array::push.apply(@exitArgs, arguments)

    describe "walk", ->
        it "invokes nodeEnter on the called node", ->
            node = {eachChild: -> undefined}
            visitor = new TestVisitor()
            visitor.walk(node)
            visitor.enterArgs.should.have.length(1)
            visitor.enterArgs.should.contain(node)


        it "invokes nodeExit on the called node", ->
            node = {eachChild: -> undefined}
            visitor = new TestVisitor()
            visitor.walk(node)
            visitor.exitArgs.should.have.length(1)
            visitor.exitArgs.should.contain(node)

            visitor = new TestVisitor(false)
            visitor.walk(node)
            visitor.exitArgs.should.have.length(1)
            visitor.exitArgs.should.contain(node)


        it "invokes eachChild with itself as a callback", ->
            cbs = []
            node = {eachChild: (cb) -> cbs.push(cb)}
            visitor = new TestVisitor()
            visitor.walk(node)
            cbs.should.have.length(1)
            cbs.should.contain(visitor.walk)


        it "skips eachChild when nodeEnter returns false", ->
            cbs = []
            node = {eachChild: (cb) -> cbs.push(cb)}
            visitor = new TestVisitor(false)
            visitor.walk(node)
            cbs.should.have.length(0)
