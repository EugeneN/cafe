CoffeeScript = require 'coffee-script'
eco = require 'eco'
fs = require 'fs'

exports.coffee = ->
    compile = (path) ->
        code = fs.readFileSync path, 'utf8'
        try
            CoffeeScript.compile fs.readFileSync path, 'utf8'
        catch err
            throw new Error (err.stack or "#{err}")

    compile.async = (path, cb) ->
        fs.readFile path, 'utf8', (err, source) ->
            unless err
                try
                    result = CoffeeScript.compile source
                catch errM
                    err = new Error (errM.stack or "#{errM}")

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
            throw new Error (e.stack or "#{e}")

    compile.async = (path, cb) ->
        if eco.precompile
            fs.readFile path, 'utf8', (err, content) ->
                unless err
                    try
                        compiled = eco.precompile content
                        cb err, "module.exports = #{compiled}"
                    catch e
                        cb (new Error (e.stack or "#{e}")), null
                else
                    cb err, null

        else
            fs.readFile path, 'utf8', (err, content) ->
                unless err
                    try
                        compiled = eco.compile content
                        cb err, compiled
                    catch e
                        cb (new Error (e.stack or "#{e}"))
                else
                    cb err, null

    {compile, ext: 'eco'}


exports.js = ->
    compile = (path) -> (fs.readFileSync path).toString()

    compile.async = (path, cb) -> fs.readFile path, cb

    {ext: 'js', compile}