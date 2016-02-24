"use strict"


module.exports = class Visitor
    walk: (node) =>
        if @nodeEnter(node) isnt false
            node.eachChild(@walk)
        @nodeExit(node)

    nodeEnter: (node) ->
        undefined

    nodeExit: (node) ->
        undefined
