fs = require 'fs'
path = require 'path'
_ = require 'underscore'
getdeps = require 'gimme-deps'
{exec} = require 'child_process'
async = require 'async'
{domonad, cont_t, lift_async, lift_sync} = require 'libmonad'

{partial, maybe_build, is_dir, is_file, has_ext, and_,
 get_mtime, newer, walk, newest, extend} = require '../../lib/utils'

OK = undefined

error_m = -> # TODO: move this to libmonad
    is_error = ([err, val]) -> (err isnt OK) and (err isnt null)

    result: (v) -> [OK, v]

    bind: (mv, f) ->
        if (is_error mv) then mv else (f mv[1])

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

    make_adaptor = (ctx, modules) ->
        type = 'npm_module'
        # TODO: set filename as path.relative mod_src , <recieved path from gimme-deps>
        harvest = (harvest_cb) ->

            _m_read_package_json = (mod_src, cb) ->
                fs.readFile (path.join mod_src, "package.json"), (err, packagejson) ->
                    packagejson = JSON.parse packagejson.toString()
                    cb [err, {mod_src, packagejson}]

            _m_execute_cafebuild = ({mod_src, packagejson}, cb) ->
                opts =
                    cwd: mod_src
                    env: process.env

                opts.env.NODE_PATH = (path.join mod_src, 'node_modules') + (if opts.env.NODE_PATH then (":#{opts.env.NODE_PATH}") else "")

                if packagejson.cafebuild?
                    child = exec packagejson.cafebuild, opts, (error, stdout, stderr) ->
                        if error
                            ctx.fb.scream stderr.replace /\n$/, ''
                            return cb ["Npm package task execution failure #{packagejson.cafebuild}, #{error}", null]

                        cb [null, {mod_src, packagejson}]
                else
                    cb [null, {mod_src, packagejson}]

            _m_get_require_dependencies = ({mod_src, packagejson}, cb) ->
                getdeps mod_src, (err, info) -> cb [err, {mod_src, packagejson, info}]

            _m_filter_require_dependencies = (ns, registered_requires, {mod_src, packagejson, info}, cb) ->
                info = info.filter (i) -> (i.module not in registered_requires) or (i.module is ns)
                cb [null, {mod_src, packagejson, info}]

            _m_fill_filtes_sources = (ns, {mod_src, packagejson, info}, fill_cb) ->
                
                npm_file_process = (_file, cb) ->
                    fs.readFile _file.path, (err, source) ->
                        fname = if _file.callee is ns
                            "index"
                        else
                            _file.callee

                        cb err, {filename: fname, source: source.toString()}
                
                async.map info, npm_file_process, (err, sources) ->
                    sources = {sources, ns}
                    fill_cb [null, {mod_src, packagejson, info, sources}]

            {mod_src} = get_paths ctx
            ns = path.basename mod_src
            registered_requires = modules.map (m) -> m.name

            seq = [
                lift_async(2, _m_read_package_json)
                lift_async(2, _m_execute_cafebuild)
                lift_async(2, _m_get_require_dependencies)
                lift_async(4, partial(_m_filter_require_dependencies, ns, registered_requires))
                lift_async(3, partial(_m_fill_filtes_sources, ns))
            ]

            domonad((cont_t error_m()), seq, mod_src) ([err, resp]) ->
                (sources = resp.sources) unless err
                harvest_cb err, sources


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