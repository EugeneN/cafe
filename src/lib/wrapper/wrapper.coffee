fs = require 'fs'
path = require 'path'
bootstrapper_file = path.join __dirname, './bootstrapper.js'

wrap_bundle = (source) ->
    """
    @source: source code of bundle.
    """

    [
        (fs.readFileSync bootstrapper_file).toString()
        source
    ].join('\n')


wrap_modules = (modules) ->
    """
    @moduels: list of dict with values {sources, ns}
    """
    (wrap_module(m.sources, m.ns) for m in modules).join('\n')


wrap_module = (sources, ns) ->
    """
    @sources: dict of key values filenames and source codes {filename, source}
    """

    [
        "require.define('#{ns}', {"
        if sources.length
            (wrap_file(s.source, s.filename, s.type) for s in sources).join ',\n'
        else
            (wrap_file sources.source, sources.filename, sources.type)
        "});\n\n"
    ].join('\n')


wrap_file = (source, filename, type) ->
    if type is 'plainjs'
        source
    else
        [
            "'#{filename}': function(exports, require, module) {(function() {"
            source
            "}).call(this);}"
        ].join('\n')


module.exports = {wrap_bundle, wrap_module, wrap_modules}
