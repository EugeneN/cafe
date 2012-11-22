stitch = new require('./stitch')
{CB_SUCCESS} = require '../defs'
path = require 'path'

exports.stitch_sources = (files, cb) ->
    """
    Accepts sources and dependencies for bundling.
        sources: {filename, source}
        dependencies: [source, source ...]

    Returns stitched module.
    """

    Package = new stitch.Package {}

    fn_without_ext = (filename) ->
        ext_length = (path.extname filename).length
        filename.slice 0, -ext_length

    pack = if files.sources
        sources = {}
        if files.sources instanceof Array
            for f in files.sources
                {filename, source} = f
                _filename = fn_without_ext filename
                sources[_filename] = {filename, source}
        else
            {filename, source} = files.sources
            _filename = fn_without_ext filename
            sources[_filename] = {filename, source}

        Package.get_result_bundle sources

    deps = files.dependencies?.join('\n')

    cb CB_SUCCESS, [deps, pack].join('\n')
