CoffeeScript = require 'coffee-script'
eco = require 'eco'
fs = require 'fs'


exports.coffee =
    ext: 'coffee'
    compile: (path) -> 
        code = fs.readFileSync path, 'utf8'
        try
            CoffeeScript.compile fs.readFileSync path, 'utf8'
        catch err
            throw new Error (CoffeeScript.helpers.prettyErrorMessage err, path, code, true)


exports.eco =
    ext: 'eco'
    compile: (path) ->
        if eco.precompile
            content = eco.precompile fs.readFileSync path, 'utf8'
            "module.exports = #{content}"
        else
            eco.compile fs.readFileSync path, 'utf8'

exports.js =
    ext: 'js'
    compile: (path) -> (fs.readFileSync path).toString()

