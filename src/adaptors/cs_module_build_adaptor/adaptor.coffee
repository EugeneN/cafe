# Prom.ua cs module adaptor blah blah

fs = require 'fs'
path = require 'path'
async = require 'async'

Compiler = require './sm_compiler'

{
    maybe_build, toArray, add, read_json_file, get_mtime, and_, or_,
    is_file, is_dir, is_debug_context, extend, walk, newest  
} = require '../../lib/utils'

{SLUG_FN, TMP_BUILD_DIR_SUFFIX, CS_ADAPTOR_PATH_SUFFIX, 
 CB_SUCCESS, CS_RUN_CONCURRENT} = require '../../defs'

build_cs_mod = (ctx, cb) ->
    {mod_src, slug_path} = get_paths ctx

    async.parallel [((is_dir_cb) -> is_dir.async mod_src, is_dir_cb), 
                    ((is_file_cb) -> is_file.async slug_path, is_file_cb)],
                    (err, res) ->
                        if not err and (and_ res...)
                            modules = [mod_src]

                            seq = modules.map (module_path) -> build_factory module_path, ctx
                            runner = (worker, cb) -> worker cb
                            if CS_RUN_CONCURRENT
                                async.map seq, runner, (err, result) -> cb err, result
                            else
                                async.series seq, (err, result) -> cb err, result
                        else
                            ctx.fb.scream "Bad module source path `#{mod_src}`, can't continue"
                            cb 'target_error'

build_factory = (mod_src, ctx) ->
    {slug_path, js_path} = get_paths ctx
    compiler_args = ctx.own_args
    emitter = ctx.emitter
    slug = read_json_file slug_path
    target_file = path.resolve js_path, slug.jsPath

    (cb) ->
        do_compile = (do_tests, cb) ->
            compiler = new Compiler mod_src, ctx, { public: js_path }
            compiler.build (err, result) ->
                if err
                    ctx.fb.scream "Compile failed: #{err}"
                    cb "Failed to compile spine app #{mod_src}", err
                else
                    if do_tests
                        compiler.build_tests (err, result) -> cb err, result
                    else
                        cb err, result

        new_cb = (ev, cb, err, result) ->
            emitter.emit ev
            cb? err, result

        if compiler_args.f
            do_compile compiler_args.t, (err, result) ->
                new_cb "COMPILE_MAYBE_FORCED", cb, err, result
        else
            maybe_build mod_src, target_file, (state, filename) ->
                if state
                    do_compile compiler_args.t, (err, result) ->
                        new_cb "COMPILE_MAYBE_COMPILED", cb, err, result
                else
                    ctx.fb.shout "#{mod_src} still hot"
                    emitter.emit "COMPILE_MAYBE_SKIPPED"
                    cb? CB_SUCCESS, filename, "COMPILE_MAYBE_SKIPPED"

get_paths = (ctx) ->
    app_root = path.resolve ctx.own_args.app_root
    module_name = ctx.own_args.mod_name
    js_path = ctx.own_args.js_path
    mod_suffix = ctx.own_args.mod_suffix

    mod_src = if ctx.own_args.src
        path.resolve ctx.own_args.src
    else
      path.resolve app_root, mod_suffix, module_name


    js_path = path.resolve app_root, (js_path or TMP_BUILD_DIR_SUFFIX)
    slug_path = path.resolve mod_src, SLUG_FN

    {mod_src, js_path, slug_path}

module.exports = do ->

    match = (ctx) ->
        {mod_src, slug_path} = get_paths ctx
        (is_dir mod_src) and (is_file slug_path)

    match.async = (ctx, cb) ->        
        {mod_src, slug_path} = get_paths ctx
        async.parallel [((is_dir_cb) -> is_dir.async mod_src, is_dir_cb), 
                        ((is_file_cb) -> is_file.async slug_path, is_file_cb)],
                        (err, res) ->
                            if not err and (and_ res...)
                                cb CB_SUCCESS, true
                            else
                                cb CB_SUCCESS, false


    make_adaptor = (ctx) ->
        type = 'csmodule'

        get_deps = (recipe_deps, cb) ->
            module_name = ctx.own_args.mod_name

            for group, deps of recipe_deps
              if group is module_name
                # making copy here because dependencies changed in toposort
                group_deps = deps.concat()

            cb CB_SUCCESS, (group_deps or [])

        harvest = (cb, opts={}) ->
            {mod_src, js_path} = get_paths ctx

            args =
                full_args:
                    compile:
                        src: mod_src
                        js_path: js_path
                own_args:
                    src: mod_src
                    js_path: js_path

            build_cs_mod (extend ctx, (extend args, opts)), cb

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
