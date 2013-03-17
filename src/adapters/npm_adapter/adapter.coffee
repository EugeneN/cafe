fs = require 'fs'
path = require 'path'
_ = require 'underscore'
getdeps = require 'gimme-deps'
async = require 'async'

{maybe_build, is_dir, is_file, has_ext, and_,
 get_mtime, newer, walk, newest, extend} = require '../../lib/utils'

CB_SUCCESS = undefined

get_paths = (ctx) ->
    app_root = path.resolve ctx.own_args.app_root
    module_name = ctx.module.path
    src = ctx.own_args.src
    mod_src = src or path.resolve app_root, module_name
    packagejson = path.resolve mod_src, "package.json"
    {mod_src, packagejson}

module.exports = do ->
    match = (ctx) ->
        {mod_src, packagejson} = get_paths ctx
        (is_dir mod_src) and (is_file packagejson)

    match.async = (ctx, cb) ->
        {mod_src, packagejson} = get_paths ctx
        async.parallel [((is_dir_cb) -> is_dir.async mod_src, is_dir_cb), 
                        ((is_file_cb) -> is_file.async packagejson, is_file_cb)],
                        (err, res) ->
                            if not err and (and_ res...)
                                cb CB_SUCCESS, true
                            else
                                cb CB_SUCCESS, false

    make_adaptor = (ctx) ->
        type = 'npm_module'

        harvest = (harvest_cb) ->
            {mod_src} = get_paths ctx

            getdeps mod_src, (err, info) ->
                ns = path.basename mod_src

                npm_file_process = (_file, cb) ->
                    fs.readFile _file.path, (err, source) ->
                        fname = if _file.callee is ns
                            "index"
                        else
                            _file.callee

                        cb err, {filename: fname, source: source.toString(), type: "commonjs"}
                async.map info, npm_file_process, (err, sources) ->
                    harvest_cb null, {sources, ns}


        last_modified = (cb) ->
            {mod_src} = get_paths ctx

            walk mod_src, (err, results) ->
                if results
                    max_time = try
                        newest (results.map (filename) -> get_mtime filename)
                    catch ex
                        0
                    cb CB_SUCCESS, max_time
                else
                    cb CB_SUCCESS, 0

        {type, harvest, last_modified}

    {match, make_adaptor}