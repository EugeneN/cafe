# Plain coffescript file adaptor blah blah
fs = require 'fs'
path = require 'path'
cs = require 'coffee-script'
{exec} = require 'child_process'
{say, shout, scream, whisper} = (require '../lib/logger') "Adaptor/Cakefile>"
{maybe_build, is_dir, is_file, has_ext, and_,
 get_mtime, newer, walk, newest, extend} = require '../lib/utils'
async = require 'async'
stitch = new require('../lib/stitch')
Package = new stitch.Package {}
_ = require 'underscore'

{FILE_ENCODING, TMP_BUILD_DIR_SUFFIX, JS_EXT,
 CAKE_BIN, CAKE_TARGET, NODE_PATH, CAKEFILE, CB_SUCCESS,
 CAFE_TMP_BUILD_ROOT_ENV_NAME, CAFE_TARGET_FN_ENV_NAME} = require '../defs'


#{put_to_tmp_storage, get_from_tmp_storage, put_to_client_storage, get_from_client_storage} = require '../services/storage'
stitch = require '../lib/stitch'

partial = (fn, args...) -> _.bind fn, null, args...


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
    cakefile = path.resolve mod_src, CAKEFILE
    target_fn = path.basename module_name + JS_EXT
    target_full_fn = get_target_fn js_path, app_root, target_fn
    tmp_build_root = js_path or path.resolve app_root, TMP_BUILD_DIR_SUFFIX

    {mod_src, cakefile, target_fn, target_full_fn, tmp_build_root}

module.exports = do ->

    match = (ctx) ->
        {mod_src, cakefile} = get_paths ctx
        (is_dir mod_src) and (is_file cakefile)

    match.async = (ctx, cb) ->
        {mod_src, cakefile} = get_paths ctx
        async.parallel [((is_dir_cb) -> is_dir.async mod_src, is_dir_cb), 
                        ((is_file_cb) -> is_file.async cakefile, is_file_cb)],
                        (err, res) ->
                            if not err and (and_ res...)
                                cb CB_SUCCESS, true
                            else
                                cb CB_SUCCESS, false

    make_adaptor = (ctx) ->
        type = 'cakefile'

        get_deps = (recipe_deps, cb) ->
            module_name = ctx.own_args.mod_name

            for group, deps of recipe_deps
                if group is module_name
                    # making copy here because dependencies changed in toposort
                    group_deps = deps.concat()

            cb CB_SUCCESS, (group_deps or [])

        harvest = (harvest_cb, opts={}) ->
            {mod_src, target_full_fn, target_fn, tmp_build_root} = get_paths ctx

            check_maybe_do = (cb) ->
              maybe_build mod_src, target_full_fn, (changed, filename) ->
                if changed or (extend ctx, opts).own_args.f
                  cb()
                else
                  cb 'Maybe skipped'

            do_cake = (cb) ->
                opts =
                    cwd: mod_src
                    env: process.env

                exec ([CAKE_BIN, CAKE_TARGET].join ' '), opts, (err, results) ->
                  cb err, results

            safe_parse_json_or_undefined = (result, cb) ->
              console.log result
              try
                cb null, (JSON.parse result)
              catch ex
                throw ex
                cb 'Parser error'

            stitching = (files, cb) ->
                sources = {}
                for [fn, source] in files
                    ext_length = (path.extname fn).length
                    filename = fn.slice 0, -ext_length
                    sources[filename] = {filename: fn, source: source}

                cb null, Package.get_result_bundle sources

            put_to_tmp_storage = (key, data, cb) ->
                fs.writeFile key, data, (err) ->
                    (cb err) if err
                    cb? null, key

            done = (err, res) ->
                switch err
                    when null
                      ctx.fb.say 'OK'
                      harvest_cb CB_SUCCESS, target_full_fn
                    when "MAYBE_SKIP"
                      ctx.fb.shout "maybe skipped"
                      harvest_cb null
                    else
                      ctx.fb.scream "not ok"
                      harvest_cb err, res

            async.waterfall([
              check_maybe_do
              do_cake
              safe_parse_json_or_undefined
              stitching
              (partial put_to_tmp_storage, target_full_fn)]
              don11e)


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
