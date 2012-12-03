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

{make_target, run_target} = require '../lib/target'
{resolve_deps, build_bundle, toposort} = require '../lib/bundler'
{say, shout, scream, whisper} = (require '../lib/logger') "Build>"
{read_json_file, add, is_dir, is_file,
 has_ext, extend, get_opt} = require '../lib/utils'

{TMP_BUILD_DIR_SUFFIX, RECIPE, RECIPE_EXT, BUILD_DEPS_FN, FILE_ENCODING, CB_SUCCESS,
 RECIPE_API_LEVEL} = require '../defs'


get_tmp_build_dir = (build_root) -> path.resolve path.join build_root, TMP_BUILD_DIR_SUFFIX

get_recipe = (recipe_path, level=0) ->
    if level > 3
        scream "Recipe inheritance chain to long"
        undefined

    else if is_file recipe_path
        recipe = read_json_file recipe_path

        if recipe?.abstract?.extends
            base_recipe_path = (path.resolve (path.dirname recipe_path),
                                             recipe.abstract.extends)

            unless base_recipe_path is recipe_path
                if (base_recipe = get_recipe base_recipe_path, level + 1)
                    extend base_recipe, recipe
                else
                    scream "Can't read base recipe #{base_recipe_path}"
                    undefined
            else
                scream "Cyclic dependency found in recipe inheritance chain"
                undefined
        else
            recipe
    else
        undefined

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

    tmp_build_dir = get_tmp_build_dir ctx.own_args.app_root
    unless is_dir tmp_build_dir
        fs.mkdirSync tmp_build_dir

    recipe_path = path.resolve ctx.own_args.app_root, (ctx.own_args.formula or RECIPE)
    recipe = get_recipe recipe_path

    unless recipe
        cb 'bad_ctx' , "Bad recipe #{recipe_path}"

    else unless recipe.abstract?.api_version is RECIPE_API_LEVEL
        cb 'bad_recipe', "Current Cafe version is not compatible with the "\
                        +"recipe.json version. Please update Cafe and try again."

    else
        cb CB_SUCCESS, recipe

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
            sorted_modules = toposort {realm, bundle}, modules
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

build_bundles = (ctx, bundles, recipe, realm, filtered_bundles, build_bundles_cb) ->
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

        build_bundle({
            realm: realm
            bundle_name: bundles[index].name
            bundle_opts: bundles[index].opts
            force_compile: force_compile
            force_bundle: force_bundle
            sorted_modules_list: filtered_bundles[index]
            build_root: get_tmp_build_dir ctx.own_args.build_root
            ctx: ctx
            cb: build_bundle_cb
        })

    build_bundles_done = (err, filtered_bundles_list) ->
        if err
            ctx.fb.scream "Level 1 build error: #{err}"
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

process_realms = (ctx, recipe, cb) ->
    show_realms ctx, recipe

    process_realm = ([realm, bundles], process_realm_cb) ->
        show_bundles ctx, realm, bundles

        map_sort_bundles ctx, bundles, recipe, realm, (err, bundles_sorted_list) ->
            filtered_bundles = filter_duplicates bundles_sorted_list
            build_bundles ctx, bundles, recipe, realm, filtered_bundles, (err, sorted_realms) ->
                process_realm_cb err, sorted_realms

    done_processing_realms = (err, sorted_realms) ->
        if err
            ctx.fb.scream "Level 0 build error: #{err}"
            cb err, sorted_realms

        else
            # Transforming from object out of list, on realm level
            result = {}
            no_changes = (sorted_realms.map ({name, bundles, not_changed}) ->
                            result[name] = bundles
                            not_changed).reduce (a, b) -> a and b

            if no_changes
                ctx.fb.shout "#{BUILD_DEPS_FN} still hot"
                cb CB_SUCCESS

            else
                if ctx.own_args.just_files
                    cb CB_SUCCESS
                else
                    fn = path.resolve (get_tmp_build_dir ctx.own_args.build_root), BUILD_DEPS_FN
                    write_build_deps_file ctx, fn, result, cb

    # Build level 0 entry point
    async.map ([k, v] for k, v of recipe.realms), process_realm, done_processing_realms


build = (ctx, build_cb) ->
    # build entry point
    # XXX why partial application fails here?
    a = do (ctx) -> (val, cb) -> get_ctx_recipe ctx, val, cb
    b = do (ctx) -> (val, cb) -> process_realms ctx, val, cb

    (compose.async check_ctx, a, b) ctx, build_cb


module.exports = make_target "build", build, help

