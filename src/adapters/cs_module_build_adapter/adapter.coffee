# Prom.ua cs module adaptor blah blah

fs = require 'fs'
path = require 'path'
async = require 'async'

{
    maybe_build, toArray, add, read_json_file, get_mtime, and_, or_,
    is_file, is_dir, is_debug_context, extend, walk, newest  
} = require '../../lib/utils'

{SLUG_FN, TMP_BUILD_DIR_SUFFIX, CS_ADAPTOR_PATH_SUFFIX, 
 CB_SUCCESS, CS_RUN_CONCURRENT, CAFE_DIR} = require '../../defs'

fn_without_ext = (filename) ->
    ext_length = (path.extname filename).length
    filename.slice 0, -ext_length

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
                                async.map seq, runner, (err, result) -> cb err, result[0]
                            else
                                async.series seq, (err, result) -> cb err, result[0]
                        else
                            ctx.fb.scream "Bad module source path `#{mod_src}`, can't continue"
                            cb 'target_error'


build_factory = (mod_src, ctx) ->
    {slug_path} = get_paths ctx
    slug = read_json_file slug_path

    (cb) ->
        do_compile = (cb) ->
            # Read slug
            slug = ctx.cafelib.utils.read_slug(mod_src, ctx.cafelib.utils.slug)
            slug.paths = slug.paths.map (p) -> path.resolve(path.join mod_src, p)

            {coffee, eco, js} = require '../../lib/compiler/compilers'
            compiler = ctx.cafelib.make_compiler [coffee, eco, js]

            try
                sources = slug.paths.map (slug_path) ->
                    paths = ctx.cafelib.utils.get_all_relative_files(
                        slug_path
                        null
                        /^[^\.].+\.coffee$|^[^\.].+\.js$|^[^\.].+\.eco$/i
                    )


                    (compiler.compile paths).map ({path: p, source: source}) ->
                        filename: fn_without_ext (path.relative slug_path, p)
                        source: source
                        type: "commonjs"

                cb null, {sources: (ctx.cafelib.utils.flatten sources), ns: (path.basename mod_src)}
                
            catch e
                cb e

        do_compile (err, result) -> cb? err, result



get_paths = (ctx) ->
    app_root = path.resolve ctx.own_args.app_root
    module_name = ctx.module.path
    mod_src = if ctx.own_args.src
        path.resolve ctx.own_args.src
    else
        path.resolve app_root, module_name

    slug_path = path.resolve mod_src, SLUG_FN
    {mod_src, slug_path}

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

            {slug_path} = get_paths ctx

            read_json_file.async slug_path, (err, slug) ->
                cb err if err
                slug_deps = slug.recipe?.concat() or []
                for group, deps of recipe_deps
                    if group is module_name
                        # making copy here because dependencies are changed in toposort
                        group_deps = deps.concat()
                
                slug_deps = slug_deps.concat(group_deps or [])

                cb CB_SUCCESS, slug_deps

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

    make_skelethon =  -> require './skelethon'

    {match, make_adaptor, make_skelethon}
