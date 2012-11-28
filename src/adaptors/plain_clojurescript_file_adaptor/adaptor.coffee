# Plain coffescript file adaptor blah blah
fs = require 'fs'
path = require 'path'
cs = require 'coffee-script'
{exec} = require 'child_process'
{is_file, has_ext, get_mtime, newer, and_} = require '../../lib/utils'
{say, shout, scream, whisper} = (require '../../lib/logger') "Adaptor/clojurescript>"
async = require 'async'

{FILE_ENCODING, TMP_BUILD_DIR_SUFFIX, CLOJURESCRIPT_EXT, JS_EXT, 
 CLOJURESCRIPT_BIN, CLOJURESCRIPT_OPTS, CB_SUCCESS} = require '../../defs'


get_target_fn = (app_root, module_name) ->
    (path.resolve app_root,
                  TMP_BUILD_DIR_SUFFIX,
                  (module_name.replace (new RegExp "\\.#{CLOJURESCRIPT_EXT}$"), '') + JS_EXT)

get_paths = (ctx) ->
    app_root = path.resolve ctx.own_args.app_root
    module_name = ctx.own_args.mod_name
    lib_dir = path.resolve app_root, TMP_BUILD_DIR_SUFFIX


    {
        source_fn: path.resolve app_root, module_name
        target_fn: (get_target_fn (path.resolve ctx.own_args.app_root),
                                  (path.basename module_name))
        lib_dir: lib_dir
        goog_lib: path.resolve lib_dir, 'cljs/core.js'
    }

module.exports = do ->

    match = (ctx) ->
        {source_fn} = get_paths ctx
        (is_file source_fn) and (has_ext source_fn, CLOJURESCRIPT_EXT)

    match.async = (ctx, cb) ->
        {source_fn} = get_paths ctx
        async.parallel [((is_file_cb) -> is_file.async source_fn, is_file_cb),
                        ((is_file_cb) -> has_ext.async source_fn, CLOJURESCRIPT_EXT, is_file_cb)],
                        (err, res) ->
                            if not err and (and_ res...)
                                cb CB_SUCCESS, true
                            else
                                cb CB_SUCCESS, false

    make_adaptor = (ctx) ->
        type = 'plain_clojurescript_file'

        get_deps = (recipe_deps, cb) ->
            module_name = ctx.own_args.mod_name

            for group, deps of recipe_deps
                if group is module_name
                    # making copy here because dependencies changed in toposort
                    group_deps = deps.concat()

            cb CB_SUCCESS, (group_deps or [])

        harvest = (cb) ->
            {source_fn, target_fn, lib_dir, goog_lib} = get_paths ctx

            CLOJURESCRIPT_OPTS = """{:output-dir "#{lib_dir}" :output-to "#{target_fn}"}"""

            cmd = "#{CLOJURESCRIPT_BIN} #{source_fn} '#{CLOJURESCRIPT_OPTS}'"

            if ctx.own_args.f or newer source_fn, target_fn
                ctx.fb.shout "Going to run: " + cmd
                exec cmd, (err, stdout, stderr) -> if err
                        ctx.fb.scream "Error compiling #{source_fn}: #{err}"
                        ctx.fb.scream "STDOUT: #{stdout}" if stdout
                        ctx.fb.scream "STDERR: #{stderr}" if stderr
                        cb CB_SUCCESS, undefined

                    else
                        ctx.fb.say "ClojureScript #{source_fn} brewed"
                        ctx.fb.say "STDOUT: #{stdout}" if stdout
                        ctx.fb.say "STDERR: #{stderr}" if stderr
                        cb CB_SUCCESS, [goog_lib, target_fn]

            else
                ctx.fb.shout "ClojureScript #{source_fn} still hot"
                cb CB_SUCCESS, [goog_lib, target_fn], "COMPILE_MAYBE_SKIPPED"

        last_modified = (cb) ->
            {source_fn} = get_paths ctx
            cb CB_SUCCESS, (get_mtime source_fn)

        {type, get_deps, harvest, last_modified}

    {match, make_adaptor}
