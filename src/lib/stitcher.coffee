stitch = new require('./stitch')
{CB_SUCCESS} = require '../defs'
path = require 'path'

exports.stitch_sources = (files, cb) ->
    """
    Accepts compiled files sources in two formats(single pair, or array):

     1. ['filename', source]
     2. [['filename', source], ['filename1', source1]]

    Returns stitched modules.
    """

    Package = new stitch.Package {}
    sources = {}

    fn_without_ext = (filename) ->
        ext_length = (path.extname filename).length
        filename.slice 0, -ext_length

    for f in files
        if f instanceof Array
            [fn, source] = f
            filename = fn_without_ext fn
            sources[filename] = {filename: fn, source: source}
        else
            [fn, source] = files
            filename = fn_without_ext fn
            sources[filename] = {filename: fn, source: source}
            break

    cb CB_SUCCESS, Package.get_result_bundle sources
