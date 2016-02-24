"use strict"
globals = require "globals"


module.exports = (envs = [], custom = {}) ->
    if typeof envs is "string"
        envs = [envs]

    result = {}
    append = (src) ->
        for key, value of src
            # if a value is read-only in one environment but writeable in
            # another, it is considered writable
            result[key] = result[key] or value

    for env in envs
        append(globals[env] or {})
    append(custom)
    result["this"] = false  # `this` is a keyword and is always read-only
    return result
