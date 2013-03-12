fs = require 'fs'
path = require 'path'
cs = require 'coffee-script'
{exec, spawn, fork} = require 'child_process'
{say, shout, scream, whisper} = (require '../../lib/logger') "Adaptor/Cakefile>"
{maybe_build, is_dir, is_file, has_ext, and_,
 get_mtime, newer, walk, newest, extend, get_cake_bin} = require '../../lib/utils'
async = require 'async'

_ = require 'underscore'

{FILE_ENCODING, TMP_BUILD_DIR_SUFFIX, JS_EXT,
 CAKE_BIN, CAKE_TARGET, NODE_PATH, CAKEFILE, CB_SUCCESS,
 CAFE_TMP_BUILD_ROOT_ENV_NAME, CAFE_TARGET_FN_ENV_NAME} = require '../../defs'


partial = (fn, args...) -> _.bind fn, null, args...

fn_without_ext = (filename) ->
    ext_length = (path.extname filename).length
    filename.slice 0, -ext_length

get_paths = (ctx) ->
    app_root = path.resolve ctx.own_args.app_root
    module_name = ctx.module.path
    src = ctx.own_args.src
    mod_src = src or path.resolve app_root, module_name
    cakefile = path.resolve mod_src, CAKEFILE

    {mod_src, cakefile}

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

        harvest = (harvest_cb) ->
            {mod_src} = get_paths ctx
            sources = null

            opts =
                cwd: mod_src
                env: process.env

            child = fork get_cake_bin(), [CAKE_TARGET], opts

            child.on 'message', (modules) ->
                child.kill()
                sources = JSON.parse modules

                sources = [sources] unless sources.length

                for module in sources
                    module.filename = fn_without_ext module.filename

            child.on 'exit', (status_code) ->
                if sources
                    ctx.fb.say "Cake module #{mod_src} was brewed"
                    harvest_cb CB_SUCCESS, {sources:sources, ns: path.basename(mod_src), mod_src: mod_src}
                else
                    ctx.fb.scream "Error during compilation of Cake module #{mod_src}"
                    harvest_cb 'fork_error', status_code


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