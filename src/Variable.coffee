"use strict"
module.exports = class Variable
    constructor: (@name, @scope, @node, @declaration) ->
        @location = @node.locationData
        @reads = []  # (scope, node) pairs
        @writes = []  # (scope, node) pairs
