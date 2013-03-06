uglify = require 'uglify-js'
fs = require 'fs'

minify = (_filename, [bundle, modules, wrapped_sources], min_cb) ->
    minified_sources = uglify.minify wrapped_sources, {fromString: true}
    fs.writeFile _filename, minified_sources.code, (err) ->
        min_cb [err, false, [bundle, modules, wrapped_sources]]


module.exports = {minify}
