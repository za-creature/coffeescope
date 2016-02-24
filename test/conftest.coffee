"use strict"
chai = require "chai"
coffeeCoverage = require "coffee-coverage"
path = require "path"


chai.should()


coverageVar = coffeeCoverage.findIstanbulVariable()
projectRoot = path.resolve(__dirname, "..")

    
coffeeCoverage.register({
    instrumentor: "istanbul"
    basePath: projectRoot
    exclude: ["/.git", "/lib", "/node_modules", "/test"]
    coverageVar: coverageVar
    writeOnExit: if coverageVar? then null else
        # Only write a coverage report if we're not running inside of Istanbul.
        path.resolve("#{projectRoot}", "coverage/coverage-coffee.json")
    initAll: true
})
