CoffeeScript = require 'coffee-script'
eco = require 'eco'
fs = require 'fs'

exports.coffee = ->
    compile = (path) ->
        code = fs.readFileSync path, 'utf8'
        try
            CoffeeScript.compile fs.readFileSync path, 'utf8'
        catch err
            throw new Error (CoffeeScript.helpers.prettyErrorMessage err, path, code, true)

    compile.async = (path, cb) ->
        fs.readFile path, 'utf8', (err, source) ->
            unless err
                try
                    result = CoffeeScript.compile source
                catch errM
                    err = new Error (CoffeeScript.helpers.prettyErrorMessage errM, path, source, true)

            cb err, result

    {ext: 'coffee', compile}


exports.eco = ->
    compile = (path) ->
        source = fs.readFileSync path, 'utf8'
        try
            if eco.precompile
                content = eco.precompile source
                "module.exports = #{content}"
            else
                eco.compile source
        catch e
            throw new Error (CoffeeScript.helpers.prettyErrorMessage e, path, source, true)

    compile.async = (path, cb) ->
        if eco.precompile
            fs.readFile path, 'utf8', (err, content) ->
                unless err
                    try
                        compiled = eco.precompile content
                        cb err, "module.exports = #{compiled}"
                    catch e
                        cb (new Error (CoffeeScript.helpers.prettyErrorMessage e, path, content, true)), null
                else
                    cb err, null

        else
            fs.readFile path, 'utf8', (err, content) ->
                unless err
                    try
                        compiled = eco.compile content
                        cb err, compiled
                    catch e
                        cb (new Error (CoffeeScript.helpers.prettyErrorMessage e, path, content, true))
                else
                    cb err, null

    {compile, ext: 'eco'}


exports.js = ->
    compile = (path) -> (fs.readFileSync path).toString()

    compile.async = (path, cb) -> fs.readFile path, cb

    {ext: 'js', compile}