fs = require 'fs'
async = require 'async'
u = require 'underscore'
path = require 'path'
mkdirp = require 'mkdirp'
{read_recipe, get_modules, get_bundles} = require './recipe_parser'
{toposort} = require './toposort'
{get_adapters} = require '../adapter'
{extend, partial, get_cafe_dir, exists} = require '../utils'
{CB_SUCCESS, RECIPE, BUILD_DIR, BUILD_DEPS_FN, ADAPTERS_PATH, ADAPTER_FN} = require '../../defs'
{get_modules_cache} = require '../modules_cache'
{wrap_bundle, wrap_modules, wrap_module} = require 'wrapper-commonjs'
{skip_or_error_m, OK} = require '../monads'
{domonad, cont_t, lift_async, lift_sync} = require 'libmonad'

CACHE_FN = 'modules'


get_modules_cache_dir = (app_root) -> path.resolve path.join get_cafe_dir(app_root), 'modules_cache' #move to defs
get_build_dir = (build_root) -> path.resolve path.join build_root, BUILD_DIR


# ======================== SAVING RESULTS ==========================================================
save_results = (modules, bundles, cache, cached_sources, ctx, save_cb) ->
    build_dir = get_build_dir ctx.own_args.build_root

    save_build_deps = (cb) ->
        serrialized_bundles = JSON.stringify((bundles.map (b) -> b.serrialize()), null, 4)
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
process_bundle = (modules, changed_modules, cached_sources, ctx, bundle, bundle_cb) ->
    # select modules for bundle
    modules = modules.filter (m) -> m.name in bundle.modules_names
    build_dir = get_build_dir ctx.own_args.build_root

    changed_modules_names = if changed_modules.length
        changed_modules.map (m) -> m.name
    else
        []

    # Check what bundles wasn been recompiled.
    was_compiled = (_bundle) ->
        u.some _bundle.modules_names, (m_name) ->
            m_name in changed_modules_names

    fill_sources = (m, cb) ->
        compiled_m = u.find changed_modules, (mod) -> mod.name is m.name

        if compiled_m?
            m.copy_sources(compiled_m.get_sources())
        else
            m.copy_sources cached_sources[m.name]

        cb null, m

    meta_changed = (modules, bundle) -> false

    if was_compiled(bundle) or meta_changed(modules, bundle)

        bundle_dir_path = path.dirname path.join(build_dir, bundle.name)
        bundle_file_path = path.join bundle_dir_path, (path.basename "#{bundle.name}.js")

        mkdirp bundle_dir_path, (err) ->
            # TODO: make modules TOPOSORT

            ordered_modules = toposort modules, ctx

            async.map ordered_modules, fill_sources, (err, modules_with_sources) ->
                bundle.set_modules modules_with_sources
                sources = (modules_with_sources.map (m) -> m.get_sources())
                bundle_sources = wrap_bundle sources.join '\n'
                # Post processing ... minify e.t.c.

                fs.writeFile bundle_file_path, bundle_sources, (err) ->
                    bundle_cb err, bundle
    else
        bundle_cb CB_SUCCESS, null


# ======================== MODULES PROCESSING ======================================================
harvest_module = (adapter, module, ctx, message, cb) ->
    message or= "Harvesting module #{module.path}"
    ctx.fb.say message
    adapter.harvest (err, sources) ->
        return(cb err) if err
        # post compile module processing sequence
        # TODO: check that sources are present
        module.set_sources wrap_module(sources.sources, sources.ns, module.type)
        cb err, module


process_module = (adapters, cached_sources, build_deps, ctx, module, module_cb) -> # TOTEST

    _m_module_path_exists = (ctx, module, cb) ->
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

    _m_build_if_force = (ctx, [module, adapter], cb) ->
        if ctx.own_args.f?
            message = "Forced harvesting #{module.name} ..."
            _adapter_ctx = extend ctx, {module}
            adapter = (adapter.make_adaptor _adapter_ctx)

            harvest_module adapter, module, ctx, message, (err, module) ->
                unless err?
                    cb [OK, true, module]
                else
                    cb ["Module compile error. Module - #{module.name}", false, undefined]
        else
            cb [OK, false, [module, adapter]]

    _m_build_if_changed = (ctx, cached_sources, [module, adapter], build_cb) ->
        _adapter_ctx = extend ctx, {module}

        _m_get_adapter = (adapter_ctx, adapter) ->
            [OK, false, (adapter.make_adaptor adapter_ctx)]

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
                if module.need_to_recompile cached_module, mtime
                    message = "Module #{module.name} was modified, harvesting ..."
                    harvest_module adapter, module, ctx, message, (err, module) ->
                        unless err?
                            cb [OK, true, module]
                        else
                            cb ["Module compile error. Module - #{module.name}", false, undefined]
                else
                    cb [OK, true, undefined]
            else
                harvest_module adapter, module, ctx, message, (err, module) ->
                    unless err?
                        cb [OK, true, module]
                    else
                        cb ["Module compile error. Module - #{module.name}", false, undefined]

        seq = [
            lift_sync(2, partial(_m_get_adapter, _adapter_ctx))
            lift_async(2, _m_get_adapter_last_modified)
            lift_async(5, partial(_m_harvest, module, ctx, cached_sources))
        ]

        (domonad (cont_t skip_or_error_m()), seq, adapter) build_cb

    seq = [
        lift_async(3, partial(_m_module_path_exists, ctx))
        lift_async(3, partial(_m_get_adapter, adapters))
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
        read_recipe.async recipe_path, 0, ([err, recipe]) -> # make recipe to return not monadic value
            cb err, {recipe}

    _get_adapters_async = (adapters_path, adapters_fn, cb) ->
        get_adapters.async adapters_path, adapters_fn, (err, adapters) ->
            cb err, {adapters}

    _get_cache_modules_async = (cache, cb) ->
        cache.get_modules_async CACHE_FN, (err, cached_sources) ->
            cb err, {cached_sources: cached_sources, cache: cache}

    _get_build_deps_async = (cb) ->
        _build_deps_fn = path.join (get_build_dir ctx.own_args.build_root), BUILD_DEPS_FN
        fs.readFile _build_deps_fn, (err, build_deps) ->
            build_deps = if err then null else JSON.parse build_deps
            cb err, {build_deps}

    get_modules_cache get_modules_cache_dir(ctx.own_args.app_root), (err, cache) ->
        (return init_cb err) if err

        async.parallel(
            [
                _read_recipe_async
                partial(_get_adapters_async, adapters_path, adapters_fn)
                partial(_get_cache_modules_async, cache)
                _get_build_deps_async
            ]
            (err, results) ->
                unless err
                    (results = results.reduce (a, b) -> extend a, b) # wrap in monad ...
                    [err, modules] = get_modules results.recipe
                    results.modules = modules

                    results.bundles = get_bundles results.recipe
                    unless results.bundles.length
                        err = "No bundles found in recipe #{recipe_path}" # wrap in monad ...

                init_cb err, results
        )


run_build_sequence = (ctx, sequence_cb) ->

    _m_init_build_sequence = (ctx, init_cb) ->
        init_build_sequence ctx, null, null, (err, init_results) ->
            init_cb [err, false, init_results]


    _m_modules_processor = (ctx
                            init_results
                            module_proc_cb) ->
        {cached_sources, recipe, adapters, modules, build_deps} = init_results

        _modules_iterator = partial(process_module,
                                    adapters, cached_sources, build_deps, ctx)

        async.map modules, _modules_iterator, (err, changed_modules) ->
            unless changed_modules.length
                module_proc_cb [OK, true, undefined]
            else
                module_proc_cb [err, false, [init_results, changed_modules]]


    _m_bundles_processor = (ctx
                            [init_results, changed_modules]
                            bundles_proc_cb) ->
        {cached_sources, build_deps, recipe, adapters, modules, bundles} = init_results

        changed_modules = changed_modules.filter (m) -> m? # removing empty

        _bundles_iterator = partial(process_bundle, modules, changed_modules, cached_sources, ctx)

        async.map bundles, _bundles_iterator, (err, proc_bundles) ->
            proc_bundles = proc_bundles.filter (b) -> b?
            unless proc_bundles.length
                ctx.fb.shout "No changes found"
                bundles_proc_cb [OK, true, undefined]
            else
                bundle_names = proc_bundles.map (b) -> b.name
                ctx.fb.say "Bundles [#{bundle_names}] was build successfully"
                bundles_proc_cb [err, false, [init_results, changed_modules, proc_bundles]]

    _m_save_results = (ctx
                       [init_results, changed_modules, proc_bundles]
                       save_cb) ->
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

    seq = [
        lift_async(2, _m_init_build_sequence)
        lift_async(3, partial(_m_modules_processor, ctx))
        lift_async(3, partial(_m_bundles_processor, ctx))
        lift_async(3, partial(_m_save_results, ctx))
    ]

    (domonad (cont_t skip_or_error_m()), seq, ctx) ([err, skip, result]) ->
        sequence_cb err, OK


module.exports = {run_build_sequence, init_build_sequence}