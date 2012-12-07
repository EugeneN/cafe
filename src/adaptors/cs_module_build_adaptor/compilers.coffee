CoffeeScript = require 'coffee-script'
eco = require 'eco'
fs = require 'fs'

exports.coffee = () ->
    ext: 'coffee'
    compile: (path) -> CoffeeScript.compile fs.readFileSync path, 'utf8'


exports.eco = () ->
    ext: 'eco'
    compile: (path) -> eco.compile fs.readFileSync path, 'utf8'

