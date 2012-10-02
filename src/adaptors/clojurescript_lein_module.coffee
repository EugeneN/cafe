# Plain coffescript file adaptor blah blah
fs = require 'fs'
path = require 'path'
cs = require 'coffee-script'
{exec} = require 'child_process'
{say, shout, scream, whisper} = (require '../lib/logger') "Adaptor/Leinmodule>"
{maybe_build, is_dir, is_file, has_ext, and_,
 get_mtime, newer, walk, newest, extend} = require '../lib/utils'
async = require 'async'

{FILE_ENCODING, TMP_BUILD_DIR_SUFFIX, JS_EXT,
 LEIN_BIN, NODE_PATH, PROJECT_CLJ, CB_SUCCESS, LEIN_ARGS,
 } = require '../defs'


get_target_fn = (js_path, app_root, target_fn) ->
    if js_path
        path.resolve js_path, target_fn
    else
        (path.resolve app_root,
                      TMP_BUILD_DIR_SUFFIX,
                      target_fn)

get_paths = (ctx) ->
    app_root = path.resolve ctx.own_args.app_root
    module_name = ctx.own_args.mod_name
    src = ctx.own_args.src
    js_path = ctx.own_args.js_path

    mod_src = src or path.resolve app_root, module_name
    project_clj = path.resolve mod_src, PROJECT_CLJ
    target_fn = path.basename module_name + JS_EXT
    target_full_fn = get_target_fn js_path, app_root, target_fn
    tmp_build_root = js_path or path.resolve app_root, TMP_BUILD_DIR_SUFFIX

    {mod_src, project_clj, target_fn, target_full_fn, tmp_build_root}

module.exports = do ->

    match = (ctx) ->
        {mod_src, project_clj} = get_paths ctx
        (is_dir mod_src) and (is_file project_clj)

    match.async = (ctx, cb) ->
        {mod_src, project_clj} = get_paths ctx
        async.parallel [((is_dir_cb) -> is_dir.async mod_src, is_dir_cb),
                        ((is_file_cb) -> is_file.async project_clj, is_file_cb)],
                        (err, res) ->
                            if not err and (and_ res...)
                                cb CB_SUCCESS, true
                            else
                                cb CB_SUCCESS, false

    make_adaptor = (ctx) ->
        type = 'clojurescript_lein_module'

        get_deps = (recipe_deps, cb) ->
            module_name = ctx.own_args.mod_name

            for group, deps of recipe_deps
                if group is module_name
                    # making copy here because dependencies changed in toposort
                    group_deps = deps.concat()

            cb CB_SUCCESS, (group_deps or [])

        harvest = (cb, opts={}) ->
            {mod_src, target_full_fn, target_fn, tmp_build_root} = get_paths ctx

            do_compile = (cb) ->
                args = [LEIN_BIN, LEIN_ARGS]
                opts =
                    cwd: mod_src
                    env: process.env

                exec (args.join ' '), opts, (err, stdout, stderr) ->
                    if err
                        ctx.fb.scream "Error compiling #{mod_src}: #{err}"
                        ctx.fb.scream ("STDOUT: #{stdout}".replace /\n$/, '') if stdout
                        ctx.fb.scream ("STDERR: #{stderr}".replace /\n$/, '') if stderr
                        cb CB_SUCCESS, undefined

                    else
                        ctx.fb.say "#{args.join ' '} #{mod_src} brewed"
                        ctx.fb.say ("STDOUT: #{stdout}".replace /\n$/, '') if stdout
                        ctx.fb.say ("STDERR: #{stderr}".replace /\n$/, '') if stderr
                        cb CB_SUCCESS, target_full_fn

            if (extend ctx, opts).own_args.f
                do_compile cb
            else
                maybe_build mod_src, target_full_fn, (state, filename) ->
                    if state
                        do_compile cb
                    else
                        ctx.fb.shout "#{mod_src} still hot"
                        ctx.emitter.emit "COMPILE_MAYBE_SKIPPED"
                        cb? CB_SUCCESS, filename, "COMPILE_MAYBE_SKIPPED"

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

        {type, get_deps, harvest, last_modified}

    {match, make_adaptor}
