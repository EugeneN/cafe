fs = require 'fs'
async = require 'async'
u = require 'underscore'
path = require 'path'
mkdirp = require '../../../third-party-lib/mkdirp'
resolve = require '../../../third-party-lib/resolve'

{domonad, cont_t, lift_async, lift_sync} = require 'libmonad'
{spawn} = require 'child_process'
{construct_cmd} = require 'easy-opts'
{wrap_bundle, wrap_modules, wrap_module} = require 'wrapper-commonjs'
{get_recipe, get_modules, get_bundles, get_modules_and_bundles_for_sequence} = require './recipe_parser'
{toposort} = require './toposort'
{get_adapters} = require '../adapter'
{extend, partial, get_cafe_dir, exists, 
get_legacy_cafe_bin_path, get_npm_mod_folder, is_array} = require '../utils'
{CB_SUCCESS, RECIPE, BUILD_DIR, BUILD_DEPS_FN,
 RECIPE_API_LEVEL, ADAPTERS_PATH, ADAPTER_FN, BUNDLE_HDR,
 NPM_MODULES_PATH, MINIFY_MIN_SUFFIX, BUILD_FILE_EXT} = require '../../defs'
{get_modules_cache} = require '../modules_cache'
{skip_or_error_m, OK} = require '../monads'
{minify} = require './cafe_minify'
{install_module} = require '../npm_tasks'
{watcher} = require '../cafe-watch'

# TODO: check if bundle path changed (compile if need and then save in new path)
# TODO: nothing happens when recipe is empty

CACHE_FN = 'modules'


get_modules_cache_dir = (app_root) -> path.resolve path.join get_cafe_dir(app_root), 'modules_cache' #move to defs
get_build_dir = (build_root) -> path.resolve path.join build_root, BUILD_DIR


# ======================== SAVING RESULTS ==========================================================
save_results = (modules, bundles, cache, cached_sources, ctx, save_cb) ->
    build_dir = get_build_dir ctx.own_args.build_root

    save_build_deps = (cb) ->
        serrialized_bundles = JSON.stringify((bundles.map (b) ->
                                             b.serrialize()), null, 4)
        fs.writeFile (path.join build_dir, BUILD_DEPS_FN), serrialized_bundles, (err) ->
            cb err

    async.parallel(
        [
            save_build_deps
            partial(cache.save_modules_async, modules, cached_sources, CACHE_FN)
        ]
        save_cb
    )


# ======================== BUNDLES PROCESSING ======================================================
process_bundle = (modules, build_deps, changed_modules, cached_sources, ctx, opts, bundle, bundle_cb) ->
    opts or={}
    _m_check_to_rebuild = (modules, build_deps, changed_modules, bundle) ->
        changed_modules_names = if changed_modules.length then\
            (changed_modules.map (m) -> m.name) else []

        was_compiled = (_bundle) ->
            u.some _bundle.modules_names, (m_name) ->
                m_name in changed_modules_names

        meta_changed = (modules, build_deps) ->
            bd_bundle = u.find build_deps, (b) -> b.name is bundle.name

            if bd_bundle?
                # check if some module is missing
                modules_names = modules.map (m) -> m.name
                deleted_module = u.find(
                    bd_bundle.modules, (m) -> m.name not in modules_names)

                if deleted_module?
                    ctx.fb.say "Module #{deleted_module.name} was removed from bundle #{bundle.name}. Rebundling ..."
                    delete cached_sources[deleted_module.name] # removing from cache
                    return true

                module_with_changed_deps = u.find modules, (m) ->

                    bd_module = u.find(bd_bundle.modules, (mod) -> mod.name is m.name)
                    unless bd_module?
                        return false

                    deps_count_not_equal = bd_module.deps.length isnt m.deps.length

                    if m.deps.length
                        deps_added = (m.deps.map((d) -> d not in bd_module.deps)
                                            .reduce((a, b) -> a or b))
                    if bd_module.deps.length
                        deps_removed = (bd_module.deps.map(
                            (d) -> d not in m.deps).reduce((a, b)-> a or b))

                    seq = [
                        deps_count_not_equal
                        deps_added
                        deps_removed
                    ]

                    seq.filter((c) -> c?).reduce((a, b) -> a or b)

                if module_with_changed_deps?
                    ctx.fb.say(
                        "Changed module #{module_with_changed_deps.name} dependencies. Rebuilding bundle #{bundle.name} ...")
                    return true
            false

        if was_compiled(bundle)
            [OK, false, [bundle, modules]]
        else if meta_changed(modules, build_deps)
            [OK, false, [bundle, modules]]
        else
            [OK, true, [bundle, modules]]

    _m_make_build_path = (ctx, bundle_dir_path, [bundle, modules], build_path_cb)->
        mkdirp bundle_dir_path, (err) -> build_path_cb [err, false, [bundle, modules]]

    _m_fill_modules_sources = ([bundle, modules], fill_sources_cb) ->
        fill_sources = (m, cb) ->
            compiled_m = u.find changed_modules, (mod) -> mod.name is m.name

            if compiled_m?
                m.copy_sources(compiled_m.get_sources())
            else
                m.copy_sources cached_sources[m.name].sources

            cb null, m

        async.map modules, fill_sources, (err, modules_with_sources) ->
            bundle.set_modules modules_with_sources
            fill_sources_cb [err, false, [bundle, modules_with_sources]]

    _m_wrap_bundle = ([bundle, modules]) ->
        sources = (modules.map (m) -> m.get_sources())
        try
            has_commonjs = modules.filter((m) -> m.type is 'commonjs').length

            wrapped_sources = if has_commonjs
                wrap_bundle (sources.join '\n'), BUNDLE_HDR
            else
                [BUNDLE_HDR, (sources.join '\n')].join '\n'

        catch ex
            err = "Failed to wrap bundle. #{ex}"

        [err, false, [bundle, modules, wrapped_sources]]

    _m_minify = (minify_fn, [bundle, modules, wrapped_sources], min_cb) ->
        if opts?.minify is true
            ctx.fb.say "Minify bundle #{bundle.name} ..."
            minify minify_fn, [bundle, modules, wrapped_sources], min_cb
        else
            min_cb [OK, false, [bundle, modules, wrapped_sources]]

    _m_write_bundle = (bundle_file_path, [bundle, modules, sources], write_cb) ->
        fs.writeFile bundle_file_path, sources, (err) ->
            err = "Failed to save bundle #{bundle.name}. #{err}" if err?
            write_cb [err, false, [bundle, modules, sources]]

    # select modules for bundle
    modules = bundle.modules_names.map (m_name) -> u.find modules, (m) -> m.name is m_name
    build_dir = get_build_dir ctx.own_args.build_root
    bundle_dir_path = path.dirname path.join(build_dir, bundle.name)
    bundle_file_path = path.join bundle_dir_path, (path.basename "#{bundle.name}#{BUILD_FILE_EXT}")
    minify_file_path = path.join bundle_dir_path, (path.basename "#{bundle.name}#{MINIFY_MIN_SUFFIX}")

    seq = [
        lift_sync(3, partial(_m_check_to_rebuild, modules, build_deps, changed_modules))
        lift_async(4, partial(_m_make_build_path, ctx, bundle_dir_path))
        lift_async(2, _m_fill_modules_sources)
        lift_sync(1, _m_wrap_bundle)
        lift_async(3, partial(_m_minify, minify_file_path))
        lift_async(3, partial(_m_write_bundle, bundle_file_path))
    ]

    (domonad (cont_t skip_or_error_m()), seq, bundle) ([err, skiped, [bundle, modules, sources]]) ->
        bundle = null if skiped is true
        bundle_cb err, bundle


# ======================== MODULES PROCESSING ======================================================
harvest_module = (adapter, module, ctx, message, cb) ->
    message or= "Harvesting module #{module.name} (#{module.path}) ..."
    ctx.fb.say message
    # TODO: handle adapter inner exception.
    adapter.harvest (err, sources) ->
        return (cb err, module) if err
        # post compile module processing sequence
        # TODO: check that sources are present
        if is_array sources
            result_sources = (sources.map (s) -> wrap_module s.sources, s.ns, module.type).join '\n'
            module.set_sources result_sources
            cb err, module
        else
            module.set_sources wrap_module(sources.sources, sources.ns, module.type)
            cb err, module


process_module = (adapters, cached_sources, build_deps, ctx, modules, module, module_cb) -> # TOTEST

    _m_module_path_exists = (ctx, module, cb) ->
        if module.get_prefix_meta().prefix is "npm"
            module_path = module.path
        else
            module_path = path.join ctx.own_args.app_root, module.path
        exists.async module_path, (err, exists) ->
            if exists is true
                cb [OK, false, module]
            else
                cb ["Module path #{module_path} for module #{module.name} was not found", false, undefined]

    _m_get_adapter = (adapters, module, cb) ->
        _adapter_ctx = extend ctx, {module}

        _adapter_match = (adapter, _cb) ->
            adapter.match.async _adapter_ctx, (err, match) -> _cb match

        async.detect adapters, _adapter_match, (adapter) ->
            unless adapter?
                cb ["No adapter found for #{module.name}", false, undefined]
            else
                cb [OK, false, [module, adapter]]

    _m_update_if_need = ([module, adapter], cb) ->
        _adapter_ctx = extend ctx, {module}
        _adapter = adapter.make_adaptor _adapter_ctx, modules

        if _adapter.hasOwnProperty "update"
            _adapter.update (err) -> cb [err, false, [module, adapter]]
        else
            cb [OK, false, [module, adapter]]

    _m_build_if_force = (ctx, [module, adapter], cb) ->
        if ctx.own_args.f? or (not build_deps)
            message = "Forced harvesting #{module.name} (#{module.path})..."
            _adapter_ctx = extend ctx, {module}
            adapter = (adapter.make_adaptor _adapter_ctx, modules) # TODO: pass modules as partial

            harvest_module adapter, module, ctx, message, (err, module) ->
                unless err?
                    cb [OK, true, module]
                else
                    cb ["Module compile error.\n Module - #{module.name}.\n #{err}", false, undefined]
        else
            cb [OK, false, [module, adapter]]


    _m_build_if_changed = (ctx, cached_sources, [module, adapter], build_cb) ->
        _adapter_ctx = extend ctx, {module}

        _m_get_adapter = (adapter_ctx, adapter) -> # TODO: move to upper _m_get_adapter
            [OK, false, (adapter.make_adaptor adapter_ctx, modules)] # TODO: pass modules as partial

        _m_get_adapter_last_modified = (adapter, cb) ->
            adapter.last_modified (err, mtime) ->
                if err?
                    return (cb ["Failed to retrieve module mtime. #{module.name}", false, undefined])
                else
                    cb [OK, false, [adapter, mtime]]

        _m_harvest = (module, ctx, cached_sources, [adapter, mtime], cb) ->
            if cached_sources?
                cached_module = cached_sources[module.name]

            if cached_module?
                if (module.need_to_recompile cached_module, mtime)
                    message = "Module #{module.name} was modified, harvesting ..."
                    harvest_module adapter, module, ctx, message, (err, module) ->
                        unless err?
                            cb [OK, true, module]
                        else
                            cb ["Module compile error.\n Module - #{module.name}.\n #{err}", false, undefined]
                else
                    cb [OK, true, undefined]
            else
                harvest_module adapter, module, ctx, message, (err, module) ->
                    unless err?
                        cb [OK, true, module]
                    else
                        cb ["Module compile error 3. Module - #{module.name}. #{err}", false, undefined]

        seq = [
            lift_sync(2, partial(_m_get_adapter, _adapter_ctx))
            lift_async(2, _m_get_adapter_last_modified)
            lift_async(5, partial(_m_harvest, module, ctx, cached_sources))
        ]

        (domonad (cont_t skip_or_error_m()), seq, adapter) build_cb

    seq = [
        lift_async(3, partial(_m_module_path_exists, ctx))
        lift_async(3, partial(_m_get_adapter, adapters))
        lift_async(2, _m_update_if_need)
        lift_async(3, partial(_m_build_if_force, ctx))
        lift_async(4, partial(_m_build_if_changed, ctx, cached_sources))
    ]

    (domonad (cont_t skip_or_error_m()), seq, module) ([err, skiped, module]) ->
        module_cb err, module


# ====================================================================================
init_build_sequence = (ctx, adapters_path, adapters_fn, init_cb) -> # TOTEST
    """
    returns:
        {cache, cached_sources, build_deps, recipe, adapters} in init_cb.
    """

    recipe_path = path.resolve ctx.own_args.app_root, (ctx.own_args.formula or RECIPE)

    _read_recipe_async = (cb) ->
        get_recipe.async recipe_path, ([err, recipe]) -> cb err, {recipe}

    _get_adapters_async = (adapters_path, adapters_fn, cb) ->
        get_adapters.async adapters_path, adapters_fn, (err, adapters) ->
            cb err, {adapters}

    _get_cache_modules_async = (cache, cb) ->
        cache.get_modules_async CACHE_FN, (err, cached_sources) ->
            if err
                ctx.fb.shout err
                cb OK, {cached_sources:null, cache}
            else
                cb err, {cached_sources: cached_sources, cache: cache}

    _get_build_deps_async = (cb) ->
        _build_deps_fn = path.join (get_build_dir ctx.own_args.build_root), BUILD_DEPS_FN
        fs.readFile _build_deps_fn, (err, build_deps) ->
            build_deps = if err
                null
            else
                try
                    JSON.parse build_deps
                catch ex
                    err_mess = "Failed to parse build deps file. #{ex}"
                    null

            cb OK, {build_deps}

    get_modules_cache get_modules_cache_dir(ctx.own_args.app_root), (err, cache) ->
        (return init_cb err) if err

        async.parallel(
            [
                _read_recipe_async
                partial(_get_adapters_async, adapters_path, adapters_fn)
                partial(_get_cache_modules_async, cache)
                _get_build_deps_async
            ]
            (err, results) -> init_cb err, results.reduce (a, b) -> extend a, b
        )


_run_build_sequence_monadic_functions =
    _m_init_build_sequence: (ctx, init_cb) ->
        init_build_sequence ctx, null, null, (err, init_results) ->
            init_cb [err, false, init_results]

    _m_check_if_old_api_version: (ctx, init_result, check_cb) -> #TOTEST
        {recipe} = init_result
        if recipe.abstract.api_version is RECIPE_API_LEVEL
            check_cb [OK, false, init_result]
        else
            legacy_cafe_bin = get_legacy_cafe_bin_path recipe.abstract.api_version
            exists.async legacy_cafe_bin, (err, status) ->
                unless status is true
                    ctx.fb.shout "Unknown api_version recipe #{recipe.abstract.api_version}"
                    check_cb [OK, true, init_result]
                else
                    ctx.fb.shout "Found old api_version #{recipe.abstract.api_version} launching old cafe"
                    cmd_args = ['--nologo', '--noupdate', '--nogrowl']
                    run = spawn legacy_cafe_bin, cmd_args.concat(construct_cmd ctx.full_args)
                    run.stdout.on 'data', (data) -> ctx.fb.say "#{data}".replace /\n$/, ''
                    run.stderr.on 'data', (data) -> ctx.fb.scream "#{data}".replace /\n$/, ''
                    run.on 'exit', (code) -> # Handle inner cafe error
                        check_cb [OK, true, init_result]

    _m_parse_modules_and_bundles: (init_result, parse_cb) -> # TOTEST
        """ Parses bundles and modules for sequence """
        {recipe} = init_result
        get_modules_and_bundles_for_sequence recipe, ([err, modules_and_bundles]) ->
            if err?
                parse_cb [err, false, undefined]
            else
                # Move this validation to separate func
                unless recipe.modules?
                    return parse_cb ["modules section is missing in recipe", false, init_result]

                unless (recipe.realms? or recipe.bundles?)
                    return parse_cb ["realms or bundles section must be present in recipe", false, init_result]

                [modules, bundles] = modules_and_bundles
                parse_cb [err, false, extend init_result, {modules, bundles}]


    _m_init_modules: (ctx, init_result, init_cb) ->
        # Processing prefixes
        {modules} = init_result
        npm_modules = modules.filter (m) -> m.get_prefix_meta()?.prefix is "npm"

        npm_mod_initializer = (mod, cb) ->
            app_root = path.resolve ctx.own_args.app_root
            resolve mod.get_prefix_meta().npm_module_name, {basedir: app_root}, (err, dirname) ->
                if dirname?
                    mod.path = path.resolve app_root, get_npm_mod_folder dirname

                    if ctx.own_args.u is true
                        install_module mod.get_prefix_meta().npm_path, app_root, (err, info) ->
                            cb err, mod
                    else
                        cb OK, mod
                else
                    (ctx.fb.scream err) if err

                    install_module mod.get_prefix_meta().npm_path, app_root, (err, info) ->
                        return(cb err, null) if err?

                        resolve mod.get_prefix_meta().npm_module_name, {basedir: app_root}, (err, dirname) ->
                            return(cb err, null) if err?
                            mod.path = path.resolve app_root, get_npm_mod_folder dirname
                            cb err, mod

        if npm_modules.length
            async.map npm_modules, npm_mod_initializer, (err, data) ->
                init_cb [err, false, init_result]
        else
            init_cb [OK, false, init_result]


    _m_modules_processor: (ctx, init_results, module_proc_cb) ->
        {cached_sources, recipe, adapters, modules, build_deps} = init_results

        _modules_iterator = partial(process_module,
                                    adapters, cached_sources, build_deps, ctx, modules)

        async.map modules, _modules_iterator, (err, changed_modules) ->
            unless changed_modules.length
                module_proc_cb [OK, true, undefined]
            else
                module_proc_cb [err, false, [init_results, changed_modules]]

    _m_bundles_processor: (ctx, [init_results, changed_modules], bundles_proc_cb) ->
        {cached_sources, build_deps, recipe, adapters, modules, bundles} = init_results
        changed_modules = changed_modules.filter (m) -> m? # removing empty

        _bundles_iterator = partial(process_bundle
                                    modules
                                    build_deps
                                    changed_modules
                                    cached_sources
                                    ctx
                                    recipe.opts
        )

        async.map bundles, _bundles_iterator, (err, proc_bundles) ->
            bundles_proc_cb [err, false, null] if err
            proc_bundles = proc_bundles.filter (b) -> b?
            unless proc_bundles.length
                ctx.fb.shout "No changes detected, skip build."
                bundles_proc_cb [OK, true, undefined]
            else
                bundle_names = proc_bundles.map (b) -> b.name
                ctx.fb.say "Bundles [#{bundle_names}] were build successfully"
                bundles_proc_cb [err, false, [init_results, changed_modules, proc_bundles]]

    _m_save_results: (ctx, [init_results, changed_modules, proc_bundles], save_cb) ->
        {cached_sources, cache, modules, bundles} = init_results

        reduce_to_object = (a, b) ->
            a[b.name] = b
            a

        tmp_bundles_obj = bundles.reduce reduce_to_object, {}

        for b in proc_bundles
            tmp_bundles_obj[b.name] = b

        merged_bundles = (v for k,v of tmp_bundles_obj)

        save_results changed_modules, merged_bundles, cache, cached_sources, ctx, (err, result) ->
            save_cb [err, false, result]


run_build = (ctx, cb) ->
    mf = _run_build_sequence_monadic_functions

    seq = [
        lift_async(2, mf._m_init_build_sequence)
        lift_async(3, partial(mf._m_check_if_old_api_version, ctx))
        lift_async(2, mf._m_parse_modules_and_bundles)
        lift_async(3, partial(mf._m_init_modules, ctx))
        lift_async(3, partial(mf._m_modules_processor, ctx))
        lift_async(3, partial(mf._m_bundles_processor, ctx))
        lift_async(3, partial(mf._m_save_results, ctx))
    ]

    (domonad (cont_t skip_or_error_m()), seq, ctx) ([err, skip, result]) ->
        cb err, OK


run_build_sequence = (ctx, sequence_cb) ->
    run_build ctx, (err, status) ->
        return (sequence_cb err) if err

        if ctx.own_args.w
            ctx.emitter.emit "NOTIFY_SUCCESS", "Build success"

            watch_handler = (path) ->
                run_build ctx, (err, status) ->
                    ctx.fb.say "watching ..."
                    unless err
                        ctx.emitter.emit "NOTIFY_SUCCESS", "Build success"
                    else
                        ctx.fb.scream err
                        ctx.emitter.emit "NOTIFY_FAILURE", err

            watcher({ paths: [ctx.own_args.app_root]
                    , change_handler: watch_handler })
            ctx.fb.say "watching ..."
        else
            sequence_cb err, OK


module.exports = {
    run_build_sequence
    init_build_sequence
    _run_build_sequence_monadic_functions
}