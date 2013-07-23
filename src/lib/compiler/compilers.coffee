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
        if eco.precompile
            content = eco.precompile fs.readFileSync path, 'utf8'
            "module.exports = #{content}"
        else
            eco.compile fs.readFileSync path, 'utf8'

    compile.async = (path, cb) ->
        if eco.precompile
            fs.readFile path, 'utf8', (err, content) ->
                compiled = eco.precompile content
                cb err, "module.exports = #{compiled}"
        else
            fs.readFile path, 'utf8', (err, content) ->
                compiled = eco.compile content
                cb err, compiled

    {compile, ext: 'eco'}


exports.js = ->
    compile = (path) -> (fs.readFileSync path).toString()

    compile.async = (path, cb) -> fs.readFile path, cb

    {ext: 'js', compile}