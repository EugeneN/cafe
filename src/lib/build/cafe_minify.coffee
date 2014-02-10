uglify = require 'uglify-js'
fs = require 'fs'
temp = require 'temp'
mv = require 'mv'
{exec} = require 'child_process'
path = require 'path'

{MINIFIER, OPTIMIZATION_LEVEL} = require '../../defs'
COMPILER = path.join __dirname, 'compiler.jar'

minify_with_uglify = (_filename, [bundle, modules, wrapped_sources], min_cb) ->
    minified_sources = uglify.minify wrapped_sources, {fromString: true}
    fs.writeFile _filename, minified_sources.code, (err) ->
        min_cb [err, false, [bundle, modules, wrapped_sources]]


# sorry for callbacks cascade
minify_with_closure_compiler = (_filename, [bundle, modules, wrapped_sources], min_cb) ->
    in_file = temp.path suffix: 'zzz'
    out_file = temp.path suffix: 'yyy'

    fs.writeFile in_file, wrapped_sources, (err) ->
        if err
            fs.unlink in_file, (uerr) ->
                min_cb [err, false, [bundle, modules, wrapped_sources]]

        else
            cmd = "java -jar #{COMPILER} --compilation_level #{OPTIMIZATION_LEVEL} --js_output_file #{out_file} #{in_file}"
            exec cmd, (err, stdout, stderr) ->
                fs.unlink in_file, (uerr) ->
                    if err
                        fs.unlink out_file, (uerr) ->
                            min_cb [err, false, [bundle, modules, wrapped_sources]]
                    else
                        mv out_file, _filename, (err) ->
                            min_cb [err, false, [bundle, modules, wrapped_sources]]

minify = switch MINIFIER
    when 'uglify'
        minify_with_uglify
    when 'closure-compiler'
        minify_with_closure_compiler
    else
        minify_with_uglify

module.exports = {minify}