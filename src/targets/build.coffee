help = [
    """
    Reads a recipe and build an application according to the recipe.
    Resolves dependencies (up to 5 lvls deep), compiles them using appropriate
    adapters, generates build deps spec for use outside of the applications.

    Parameters:
        - app_root    - directory with client-side sources

        - build_root  - directory to put built code into

        - formula     - formula to use for each particular build,
                        'recipe.json' by default

    There may be 3 types of dependencies in recipe.json
    and in `recipe` array in slug.json files

        1. CoffeeScript modules
        2. JavaScript group (i.e. `jquery` is a group that includes
           jquery itself but also jquery-ui and jquery.cookie)
        3. JavaScript file

    1) CoffeeScript modules are specified by names. Appropriate adapter will look
       for the respective location on th filesystem.

    (2) JavaScript groups are described in recipe.json in `deps`. Path specifications
        must match those of (3).

        Example (in recipe.json):
            "deps":{
                "utils": [
                    "shopping_cart.js",
                    "uaprom_common.js",
                    "utils.js"
                ]
            },

    (3) JavaScript files must be specified by a path relative to
        the recipe.json location.

        Example:
            "baselib/uaprom.js",                // <- file in build_root
            "baselib/jquery/jquery-1.6.2.js",   // <- file in subdir jquery of build_root

    Each particular adaptor may use it's own algorythms for dependencies resolving
    and filesystem lookup.



    """
]


fs = require 'fs'
path = require 'path'
async = require 'async'
{compose, map, partial} = require 'functools'
{spawn} = require 'child_process'

{make_target, run_target} = require '../lib/target'
{resolve_deps, build_bundle, toposort} = require '../lib/bundler'
{read_recipe} = require '../lib/build/recipe_reader'

{read_json_file, add, is_dir, is_file,
 has_ext, extend, get_opt, get_cafe_dir, partial,
 get_legacy_cafe_bin_path, filter_dict } = require '../lib/utils'

{TMP_BUILD_DIR_SUFFIX, RECIPE, RECIPE_EXT, BUILD_DEPS_FN, FILE_ENCODING, CB_SUCCESS,
 RECIPE_API_LEVEL} = require '../defs'


get_tmp_build_dir = (build_root) -> path.resolve path.join build_root, TMP_BUILD_DIR_SUFFIX
get_modules_cache_dir = (app_root) -> path.resolve path.join get_cafe_dir(app_root), 'modules_cache'

show_realms = (ctx, recipe) ->
    ctx.fb.say "Realms found: #{(realm for realm of recipe.realms).join ', '}"

show_bundles = (ctx, realm, bundles) ->
    ctx.fb.say "Bundles found for #{realm}: #{(bundle.name for bundle in bundles).join ', '}"

write_build_deps_file = (ctx, fn, deps, cb) ->
    fs.writeFile fn, JSON.stringify(deps, null, 4), FILE_ENCODING, (err) ->
        if err
            ctx.fb.scream "Failed to write build deps file #{fn}: #{err}."
            cb "fs_error", err
        else
            ctx.fb.say "Build deps file #{fn} written."
            cb CB_SUCCESS

check_ctx = (ctx, cb) ->
    unless ctx.own_args.app_root and ctx.own_args.build_root
        cb ["app_root and/or build_root arguments missing", 'bad_ctx']

    else unless is_dir ctx.own_args.app_root
        cb ["App root #{ctx.own_args.app_root} is not a directory", 'bad_ctx']

    else
        cb CB_SUCCESS, true

get_ctx_recipe = (ctx, ctx_is_valid, cb) ->
    unless ctx_is_valid
        return cb 'bad_ctx'

    recipe_path = path.resolve ctx.own_args.app_root, (ctx.own_args.formula or RECIPE)
    [error, recipe] = read_recipe recipe_path

    unless recipe
        cb 'bad_ctx' , "Bad recipe #{error}"

    if recipe.abstract.api_version is RECIPE_API_LEVEL # if we got the latest version
        cb CB_SUCCESS, recipe
    else
        arg1 = (arg) -> "-#{arg}"
        arg2 = (arg, val) -> "--#{arg}#{if val is undefined then '' else '=' + val}"
        format_arg = (arg, val) -> if val is true then arg1(arg) else arg2(arg, val)

        ctx.fb.shout "Found old apiversion in recipe #{recipe.abstract.api_version}"

        if (legacy_cafe_bin = get_legacy_cafe_bin_path recipe.abstract.api_version)
            cmd_args = ['--nologo', '--noupdate', '--nogrowl']

            cmd_args.push(format_arg(arg, val)) for arg, val of ctx.global

            # adding commands and their arguments
            for command, args of filter_dict(ctx.full_args, (k, v) -> k not in ['global'])
                cmd_args.push "#{command}"
                cmd_args.push(format_arg(arg, val)) for arg, val of args

            run = spawn legacy_cafe_bin, cmd_args

            run.stdout.on 'data', (data) -> ctx.fb.say "#{data}".replace /\n$/, ''
            run.stderr.on 'data', (data) -> ctx.fb.scream "#{data}".replace /\n$/, ''
            run.on 'exit', (code) ->
                cb 'stop'
        else
            cb 'bad_recipe', "Current Cafe version is not compatible with the "\
                +"recipe.json version. Please update Cafe and try again."


map_sort_bundles = (ctx, bundles, recipe, realm, map_sort_bundles_cb) ->
    resolve_sub_deps = (found_modules, resolve_sub_deps_cb) ->
        first_level_deps = add (d.deps for m, d of found_modules)...

        # now we have to add dependencies of modules in `modules_list` to
        # `modules_list` to be able to make topological sorting
        args =
            modules: first_level_deps
            app_root: ctx.own_args.app_root
            recipe_deps: recipe.deps
            ctx: ctx

        resolve_deps args, (err, found_modules_second_level) ->
            for module, deps of found_modules_second_level when not (module in found_modules)
                found_modules[module] = deps

            resolve_sub_deps_cb CB_SUCCESS, found_modules

    resolve_all_deps = (args, resolve_all_deps_cb) ->
        async.waterfall((add [(do (args) -> (cb) -> resolve_deps args, cb)],
                             ([1..5].map -> resolve_sub_deps)), resolve_all_deps_cb)


    sort_bundles = (bundle, sort_bundles_cb) ->
        args =
            modules: bundle.modules
            app_root: ctx.own_args.app_root
            recipe_deps: recipe.deps
            ctx: ctx

        resolve_all_deps args, (err, modules) ->
            sorted_modules = toposort {realm, bundle}, modules, ctx
            sort_bundles_cb CB_SUCCESS, sorted_modules

    # map.async sort_bundles, bundles, map_sort_bundles_cb
    async.map bundles, sort_bundles, map_sort_bundles_cb

filter_duplicates = (bundles_sorted_list) ->
    # Remove excessive dependencies from bundles
    # That is, if some module was imported in this realm's previous bundle,
    # don't bundle it to the next one
    # e.g. if 'jquery' is in a 'core' bundle, don't put it into a 'common'
    filtered_bundles = [0...bundles_sorted_list.length].map (i) ->
        prev_bundles = (add bundles_sorted_list[0...i]...) or []
        prev_bundles_names = (m.name for m in prev_bundles)

        (m for m in bundles_sorted_list[i] when not(m.name in prev_bundles_names))

    filtered_bundles

build_bundles = (ctx, bundles, recipe, build_deps, realm, filtered_bundles, build_bundles_cb) ->
    # Build bundles and return list of bundles for exporting to result json file

    build_bundle_wrapper = (index, build_bundle_wrapper_cb) ->
        maybe_minify = get_opt 'minify', bundles[index].opts, recipe.opts
        force_compile = get_opt 'force_compile', bundles[index].opts, recipe.opts
        force_bundle = get_opt 'force_bundle', bundles[index].opts, recipe.opts

        build_bundle_cb = (err, res) ->
            if err
                build_bundle_wrapper_cb err, res

            else
                [realm, bundle_name, not_changed] = res
                mod_status = {}
                mod_status[realm] = {}
                mod_status[realm][bundle_name] = not_changed

                post_build_bundle_cb = ->
                    build_bundle_wrapper_cb(
                        CB_SUCCESS
                        {
                            name: bundles[index].name
                            modules: filtered_bundles[index]
                            not_changed: mod_status[realm][bundles[index].name]
                        }
                    )

                if maybe_minify
                    args =
                        global:
                            debug: true
                        minify:
                            src: path.join (get_tmp_build_dir ctx.own_args.build_root), realm
                            pattern: bundles[index].name

                    run_target 'minify', args, ctx, post_build_bundle_cb
                else
                    post_build_bundle_cb()

        try
            if build_deps and build_deps[realm][bundles[index].name]?
                build_deps_modules_names = (m.name for m in build_deps[realm][bundles[index].name])
                filtered_modules_names = (m.name for m in filtered_bundles[index])

                is_recipe_bundle_changed = not (build_deps_modules_names.map((m) -> m in filtered_modules_names).reduce (a, b) -> a and b)
                is_bundle_recipe_changed = not (filtered_modules_names.map((m) -> m in build_deps_modules_names).reduce (a, b) -> a and b)
            else
                force_compile = true
                
        catch ex
            force_compile = true

        build_bundle({
            realm: realm
            bundle_name: bundles[index].name
            bundle_opts: bundles[index].opts
            force_compile: force_compile or (is_recipe_bundle_changed or is_bundle_recipe_changed)
            force_bundle: force_bundle
            sorted_modules_list: filtered_bundles[index]
            build_root: (get_tmp_build_dir ctx.own_args.build_root)
            cache_root: (get_modules_cache_dir ctx.own_args.app_root)
            build_bundle_cb: build_bundle_cb
            recipe
            ctx: ctx
        })

    build_bundles_done = (err, filtered_bundles_list) ->
        if err
            build_bundles_cb err

        else
            # Transforming from object out of list, on bundle level
            # We need this for more comfort build_deps.json handling later
            result = {}
            no_changes = (filtered_bundles_list.map ({name, modules, not_changed}) ->
                result[name] = modules
                not_changed).reduce (a, b) -> a and b

            # Returns object with Realm name and it's sorted bundles
            build_bundles_cb(CB_SUCCESS,
                {
                    name: realm
                    bundles: result
                    not_changed: no_changes
                }
            )

    # Build level 1 entry point
    async.map [0...filtered_bundles.length], build_bundle_wrapper, build_bundles_done

process_realms = (ctx, recipe, build_deps, cb) ->
    show_realms ctx, recipe

    process_realm = ([realm, bundles], process_realm_cb) ->
        #show_bundles ctx, realm, bundles

        map_sort_bundles ctx, bundles, recipe, realm, (err, bundles_sorted_list) ->
            filtered_bundles = filter_duplicates bundles_sorted_list
            build_bundles ctx, bundles, recipe, build_deps, realm, filtered_bundles, (err, sorted_realms) ->
                process_realm_cb err, sorted_realms

    done_processing_realms = (err, sorted_realms) ->
        if err
            cb err, sorted_realms

        else
            # Transforming from object out of list, on realm level
            result = {}
            no_changes = (sorted_realms.map ({name, bundles, not_changed}) ->
                            result[name] = bundles
                            not_changed).reduce (a, b) -> a and b

            if no_changes
                #ctx.fb.shout "#{BUILD_DEPS_FN} still hot"
                cb CB_SUCCESS

            else
                if ctx.own_args.just_compile
                    cb CB_SUCCESS
                else
                    fn = path.resolve (get_tmp_build_dir ctx.own_args.build_root), BUILD_DEPS_FN
                    write_build_deps_file ctx, fn, result, cb

    # Build level 0 entry point
    async.map(
        ([k, v] for k, v of recipe.realms)
        process_realm
        done_processing_realms
    )


build = (ctx, build_cb) ->
    # build entry point
    # XXX why partial application fails here?
    try
        build_deps = JSON.parse fs.readFileSync(path.resolve (get_tmp_build_dir ctx.own_args.build_root), BUILD_DEPS_FN)
    catch e
        ctx.fb.shout "Build deps json is not found - forcing compile"

    a = do (ctx) -> (val, cb) -> get_ctx_recipe ctx, val, cb
    b = do (ctx) -> (val, cb) -> process_realms ctx, val, build_deps, cb

    (compose.async check_ctx, a, b) ctx, build_cb


module.exports = make_target "build", build, help

