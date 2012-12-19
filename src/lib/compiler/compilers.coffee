CoffeeScript = require 'coffee-script'
eco = require 'eco'
fs = require 'fs'

exports.coffee =
    ext: 'coffee'
    compile: (path) -> CoffeeScript.compile fs.readFileSync path, 'utf8'


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

