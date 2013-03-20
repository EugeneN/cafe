fs = require 'fs'
path = require 'path'
_ = require 'underscore'
{run_install_in_dir} = require './npm_tasks'
getdeps = require 'gimme-deps'
{exec} = require 'child_process'
async = require 'async'
{domonad, cont_t, lift_async, lift_sync} = require 'libmonad'

{partial, maybe_build, is_dir, is_file, has_ext, and_,
 get_mtime, newer, walk, newest, extend, flatten, fn_without_ext} = require '../../lib/utils'

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


            _m_run_npm_install = ({mod_src, packagejson}, npm_install_cb) ->
                fs.exists path.join(path.resolve(mod_src), 'node_modules'), (exists) ->
                    if exists
                        npm_install_cb [null, {mod_src, packagejson}]
                    else
                        deps = (k for k, v of packagejson.dependencies)
                        if deps.length # if has deps
                            run_install_in_dir path.resolve(mod_src), (err, data) ->
                                npm_install_cb [err, {mod_src, packagejson}]
                        else
                            npm_install_cb [err, {mod_src, packagejson}]


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
                getdeps mod_src, (err, info) -> 
                    cb [err, {mod_src, packagejson, info}]

            _m_filter_require_dependencies = (ns, registered_requires, {mod_src, packagejson, info}, cb) ->
                info = info.filter (i) -> (i.module not in registered_requires) or (i.module is ns)
                cb [null, {mod_src, packagejson, info}]

            _m_fill_filtes_sources = (ns, {mod_src, packagejson, info}, fill_cb) ->
                
                npm_mod_process = (mod, module_process_cb) ->
                    _m_get_main_file = (mod_src, mod, get_main_file_cb) ->
                        main_file = null
                        if mod.main_file?
                            main_file = _.find mod.files, (f) -> f.path is mod.main_file # TODO: check null
                            fs.readFile mod.main_file, (err, source) ->
                                filename = if path.basename(mod.module_path) isnt path.basename(mod_src) # if is root
                                    path.join path.basename(mod.module_path), path.relative mod.module_path, main_file.path
                                else
                                    path.relative mod.module_path, main_file.path

                                main_file = {filename, source}
                                get_main_file_cb [err, {mod, main_file}]

                        else
                            get_main_file_cb [null, {mod, main_file}]


                    _m_link_main_to_index = (mod_src, {mod, main_file}, link_main_to_index_cb) ->
                        files = []

                        if main_file?
                            if path.basename(mod.module_path) is path.basename(mod_src)
                                if path.basename(main_file.filename) isnt "index.js"
                                    source = "module.exports = require('#{fn_without_ext main_file.filename}')"
                                    files.push {filename:"index.js", source}
                            else
                                if path.basename(main_file.filename) isnt "index.js"
                                    source = "module.exports = require('#{fn_without_ext main_file.filename}')"
                                    filename = "#{path.basename(mod.module_path)}/index.js"
                                    files.push {filename, source} 

                        link_main_to_index_cb [null, {mod, main_file, files}]


                    _m_files_process = (mod_src, {mod, main_file, files}, file_process_cb) ->

                        file_process = (file, file_parse_cb) ->

                            fs.readFile file.path, (err, source) ->
                                filename = if path.basename(mod.module_path) isnt path.basename(mod_src) # is root module
                                    path.join path.basename(mod.module_path), path.relative mod.module_path, file.path
                                else
                                    path.relative mod.module_path, file.path
                                file_parse_cb err, {filename, source}

                        module_files = mod.files.filter (m) -> m.path isnt mod.main_file # select all except main files

                        async.map module_files, file_process, (err, mod_files) ->
                            mod_files = mod_files.concat files

                            res_mod_files = if main_file?
                                mod_files.concat [main_file]
                            else
                                mod_files

                            file_process_cb [err, res_mod_files]

                    seq = [
                        lift_async(3, partial(_m_get_main_file, mod_src))
                        lift_async(3, partial(_m_link_main_to_index, mod_src))
                        lift_async(3, partial(_m_files_process, mod_src))
                    ]

                    domonad((cont_t error_m()), seq, mod) ([err, parsed_files]) ->
                        module_process_cb err, parsed_files
                
                async.map info, npm_mod_process, (err, sources) ->
                    sources = flatten(sources).map (s) ->
                        s.filename = fn_without_ext s.filename
                        s

                    sources = {sources, ns}
                    fill_cb [null, {mod_src, packagejson, info, sources}]

            {mod_src} = get_paths ctx
            ns = path.basename mod_src
            registered_requires = modules.map (m) -> m.name

            seq = [
                lift_async(2, _m_read_package_json)
                lift_async(2, _m_run_npm_install)
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