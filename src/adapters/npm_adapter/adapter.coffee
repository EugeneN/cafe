fs = require 'fs'
path = require 'path'
_ = require 'underscore'
{run_install_in_dir, install_module} = require '../../lib/npm_tasks'
getdeps = require 'gimme-deps'
{exec} = require 'child_process'
async = require 'async'
{domonad, cont_t, lift_async, lift_sync} = require 'libmonad'
resolve = require 'resolve'

{partial, maybe_build, is_dir, is_file, has_ext, and_,
 get_mtime, newer, walk, newest, extend,
 flatten, fn_without_ext, get_npm_mod_folder} = require '../../lib/utils'

CB_SUCCESS = undefined

# TODO: move this to libmonad
OK = undefined
ok = (v) -> [OK, v]
nok = (err, v) -> [err, v]

error_m = ->
    is_error = ([err, val]) -> (err isnt OK) and (err isnt null)

    result: (v) -> [OK, v]

    bind: (mv, f) ->
        if (is_error mv) then mv else (f mv[1])

get_paths = (ctx, ctx_cb) ->
    app_root = path.resolve ctx.own_args.app_root
    module_name = ctx.module.path

    resolve module_name, {basedir: app_root}, (err, dirname) ->
        if err
            ctx_cb err, {}
        else
            mod_src = path.resolve app_root, (get_npm_mod_folder dirname)
            packagejson = path.resolve mod_src, "package.json"

            ctx_cb OK, {mod_src, packagejson}

module.exports = do ->
    match = (ctx) -> throw "Sync match not available for npm adapter"

    match.async = (ctx, cb) ->
        get_paths ctx, (err, {mod_src, packagejson}) ->
            if err
                cb OK, false
            else
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

            _m_read_package_json = ({mod_src, packagejson}, cb) ->
                fs.readFile packagejson, (err, data) ->
                    if err
                        cb (nok err)
                    else
                        cb (ok {mod_src: mod_src, packagejson: (JSON.parse data.toString())})

            _m_run_npm_install = ({mod_src, packagejson}, npm_install_cb) ->
                fs.exists path.join(path.resolve(mod_src), 'node_modules'), (exists) ->
                    if exists is true
                        npm_install_cb (ok {mod_src, packagejson})

                    else
                        deps = (k for k, v of packagejson.dependencies)
                        if deps.length # if has deps
                            run_install_in_dir (path.resolve mod_src), (err, data) ->
                                if err
                                    npm_install_cb (nok err)
                                else
                                    npm_install_cb (ok {mod_src, packagejson})
                        else
                            npm_install_cb (ok {mod_src, packagejson})

            _m_execute_cafebuild = ({mod_src, packagejson}, cb) ->
                opts =
                    cwd: mod_src
                    env: process.env

                opts.env.NODE_PATH = (path.join mod_src, 'node_modules') # + (if opts.env.NODE_PATH then (":#{opts.env.NODE_PATH}") else "")

                if packagejson.cafebuild?
                    child = exec packagejson.cafebuild, opts, (error, stdout, stderr) ->
                        if error
                            ctx.fb.scream stderr.replace /\n$/, ''
                            return cb (nok "Npm package task execution failure #{packagejson.cafebuild}, #{error}")

                        cb (ok {mod_src, packagejson})
                else
                    cb (ok {mod_src, packagejson})

            _m_get_require_dependencies = ({mod_src, packagejson}, cb) ->
                getdeps mod_src, (err, info) ->
                    if err
                        cb (nok err)
                    else
                        cb (ok {mod_src, packagejson, info})

            _m_filter_require_dependencies = (ns, registered_requires, {mod_src, packagejson, info}, cb) ->
                unique_reducer = (a, b) ->
                    unless b.module of a
                        a[b.module] = b
                    a

                # TODO filter duplicates by module name which is used in require
                info = info.filter (i) -> (i.module not in registered_requires) or (i.module is ns)
                info = info.reduce unique_reducer, {}
                info = (v for k, v of info)
                cb (ok {mod_src, packagejson, info})

            _m_fill_filter_sources = (ns, {mod_src, packagejson, info}, fill_cb) ->

                npm_mod_process = (mod, module_process_cb) ->

                    _m_get_main_file = (mod_src, mod, get_main_file_cb) ->
                        main_file = null
                        if mod.main_file?
                            main_file = _.find mod.files, (f) -> f.path is mod.main_file # TODO: check null
                            fs.readFile mod.main_file, (err, source) ->
                                if err
                                    get_main_file_cb (nok err)
                                else

                                    filename = path.relative mod.module_path, main_file.path
                                    main_file = {filename, source}
                                    get_main_file_cb (ok {mod, main_file})

                        else
                            get_main_file_cb (ok {mod, main_file})

                    _m_link_main_to_index = (mod_src, {mod, main_file}, link_main_to_index_cb) ->
                        files = []

                        if main_file?
                            if (path.basename main_file.filename) isnt "index.js" #FIXME
                                source = "module.exports = require('#{fn_without_ext main_file.filename}')"
                                filename = "index.js"
                                files.push {filename, source}

                        link_main_to_index_cb (ok {mod, main_file, files})

                    _m_check_includes = (module, mod_src, {mod, main_file, files}, check_includes_cb) ->
                        if path.basename(mod.module_path) isnt (path.basename mod_src) # if not root
                            check_includes_cb (ok {mod, main_file, files})
                        else
                            if module.get_prefix_meta()?.include?.length
                                _files = module.get_prefix_meta().include.map (f) -> {path: path.join(mod_src, f)}
                                mod.files = mod.files.concat _files
                                check_includes_cb (ok {mod, main_file, files})
                            else
                                check_includes_cb (ok {mod, main_file, files})

                    _m_files_process = (mod_src, {mod, main_file, files}, file_process_cb) ->

                        file_process = (file, file_parse_cb) ->
                            fs.readFile file.path, (err, source) ->
                                if err
                                    file_parse_cb err
                                else
                                    filename = path.relative mod.module_path, file.path
                                    file_parse_cb CB_SUCCESS, {filename, source}

                        module_files = mod.files.filter (m) -> m.path isnt mod.main_file # select all except main files

                        async.map module_files, file_process, (err, mod_files) ->
                            if err
                                file_process_cb (nok err)
                            else
                                mod_files = mod_files.concat files
                                mod_files = if main_file? then mod_files.concat [main_file] else mod_files

                                sources = flatten(mod_files).map (s) ->
                                    s.filename = fn_without_ext s.filename
                                    s

                                ns = if path.basename(mod.module_path) isnt (path.basename mod_src)
                                    path.basename mod.module_path
                                else
                                    ns

                                result = {sources, ns}
                                file_process_cb (ok result)

                    seq = [
                        lift_async 3, (partial _m_get_main_file, mod_src)
                        lift_async 3, (partial _m_link_main_to_index, mod_src)
                        lift_async 4, (partial _m_check_includes, ctx.module, mod_src)
                        lift_async 3, (partial _m_files_process, mod_src)
                    ]

                    (domonad (cont_t error_m()), seq, mod) ([err, parsed_files]) ->
                        module_process_cb err, parsed_files

                async.map info, npm_mod_process, (err, sources) ->
                    if err
                        fill_cb (nok err)
                    else
                        fill_cb (ok {mod_src, packagejson, info, sources})


            get_paths ctx, (err, {mod_src, packagejson}) ->
                ns = path.basename mod_src
                registered_requires = modules.map (m) -> m.name

                seq = [
                    lift_async 2, _m_read_package_json
                    lift_async 2, _m_run_npm_install
                    lift_async 2, _m_execute_cafebuild
                    lift_async 2, _m_get_require_dependencies
                    lift_async 4, (partial _m_filter_require_dependencies, ns, registered_requires)
                    lift_async 3, (partial _m_fill_filter_sources, ns)
                ]

                (domonad (cont_t error_m()), seq, {mod_src, packagejson}) ([err, resp]) ->
                    # harvest_cb isn't a monadic continuation
                    if err then (harvest_cb err) else (harvest_cb CB_SUCCESS, resp.sources)

        last_modified = (cb) ->
            mod_src = ctx.module.path

            walk mod_src, (err, results) ->
                if results
                    max_time = try
                        newest (results.map (filename) -> get_mtime filename)
                    catch ex
                        0

                    cb CB_SUCCESS, max_time
                else
                    cb CB_SUCCESS, 0

        update = (update_cb) ->  # TODO: rewrite in monadic way !!!
            # Checking version
            get_paths ctx, (err, {mod_src, packagejson}) ->
                return update_cb(err) if err

                fs.readFile packagejson, (err, data) ->
                    return update_cb(err) if err
                        
                    module_version = ctx.module.get_prefix_meta().version
                    package_json_version = JSON.parse(data.toString())?.version

                    if module_version?
                        if package_json_version isnt module_version
                            ctx.fb.say "Changing npm module version from #{package_json_version} to #{module_version}"
                            install_module ctx.module.get_prefix_meta().npm_path, (path.resolve ctx.own_args.app_root), (err, data) ->
                                update_cb err
                        else
                            update_cb()
                    else
                        update_cb()

        {type, harvest, last_modified, update}

    {match, make_adaptor}