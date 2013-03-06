fs = require 'fs'
path = require 'path'
bootstrapper_file = path.join __dirname, './bootstrapper.js'
COMMON_JS = 'commonjs'
PLAIN_JS = 'plainjs'

wrap_bundle = (source, pre_header=null) ->
    """
    @source: source code of bundle.
    """

    [
        pre_header or ''
        (fs.readFileSync bootstrapper_file).toString()
        source
    ].join('\n')


wrap_modules = (modules) ->
    """
    @modules: list of dicts {sources, ns}
            [
                {ns:'namespace', sources: {filename: source}}
                .
                .
                .
            ]
    """
    
    ((wrap_module m.sources, m.ns) for m in modules).join('\n')


wrap_module = (sources, ns) ->
    """
    @sources: dict of key values filenames and source codes {filename, source}
    """

    if sources.length
        [
            (s.source for s in sources when s.type is PLAIN_JS).join '\n'
            "require.define('#{ns}', {"
            ((wrap_file s.source, s.filename, s.type, ns) for s in sources when s.type is COMMON_JS).join ',\n'
            "});\n"
        ].join('\n')
    else
        if sources.type is COMMON_JS
            wrap_module [sources], ns
        else
            [
                "/*ZB: #{sources.filename} */"
                "#{sources.source};"
            ].join '\n'



wrap_file = (source, filename, type, ns) ->
    [
        "/*ZB:  #{ns}/#{filename} */"
        "'#{filename}': function(exports, require, module) {(function() {"
        source
        "}).call(this);}"
    ].join('\n')


module.exports = {wrap_bundle, wrap_module, wrap_modules}
