fs = require 'fs'
async = require 'async'
u = require 'underscore'
path = require 'path'
mkdirp = require 'mkdirp'
{read_recipe, get_modules, get_bundles} = require './recipe_parser'
{get_adapters} = require '../adapter'
{extend, partial, get_cafe_dir} = require '../utils'
{CB_SUCCESS, RECIPE, BUILD_DIR, BUILD_DEPS_FN, ADAPTERS_PATH, ADAPTER_FN} = require '../../defs'
{get_modules_cache} = require '../modules_cache'
{wrap_bundle, wrap_modules, wrap_module} = require 'wrapper-commonjs'
CACHE_FN = 'modules'


get_modules_cache_dir = (app_root) -> path.resolve path.join get_cafe_dir(app_root), 'modules_cache' #move to defs
get_build_dir = (build_root) -> path.resolve path.join build_root, BUILD_DIR


# ======================== SAVING RESULTS ==========================================================
save_results = (modules, bundles, cache, cached_sources, ctx, save_cb) ->
    build_dir = get_build_dir ctx.own_args.build_root

    save_build_deps = (modules, cb) ->
        serrialized_bundles = JSON.stringify((bundles.map (b) -> b.serrialize()), null, 4)
        fs.writeFile (path.join build_dir, BUILD_DEPS_FN), serrialized_bundles, (err) ->
            cb err

    async.parallel(
        [
            partial(save_build_deps, modules)
            partial(cache.save_modules_async, modules, cached_sources, CACHE_FN)
        ]
        save_cb
    )


# ======================== BUNDLES PROCESSING ======================================================
process_bundle = (modules, cached_sources, ctx, bundle, bundle_cb) ->
    # select modules for bundle
    modules = modules.filter (m) -> m.name in bundle.modules_names
    build_dir = get_build_dir ctx.own_args.build_root

    # Check what bundles wasn been recompiled.
    was_compiled = (_modules, _bundle) ->
        # TODO: compare with build_deps
        u.some _bundle.modules_names, (m_name) ->
            m = u.find _modules, (mod) -> mod.name is m_name
            m.has_sources()? # if atleast one module was compiled

    # check if some modules metadata was changed.
    meta_changed = () -> false

    fill_sources = (m, cb) ->
        m.copy_sources(cached_sources[m.name].sources) unless m.has_sources()
        cb null, m # temporary mock.

    if was_compiled(modules, bundle) or meta_changed(modules, bundle)

        bundle_dir_path = path.dirname path.join(build_dir, bundle.name)
        bundle_file_path = path.join bundle_dir_path, (path.basename "#{bundle.name}.js")

        mkdirp bundle_dir_path, (err) ->
            # TODO: make modules TOPOSORT
            async.map modules, fill_sources, (err, modules_with_sources) ->
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


process_module = (adapters, cached_sources, build_deps, ctx, module, module_cb) ->
    _adapter_ctx = extend ctx, {module}

    _adapter_match = (adapter, cb) ->
        adapter.match.async _adapter_ctx, (err, match) -> cb match

    async.detect adapters, _adapter_match, (adapter) ->
        module_cb "No adapter found for #{module.name} module" unless adapter?
        adapter = adapter.make_adaptor _adapter_ctx # TODO: ugly....

        unless ctx.own_args.f
            cached_module = cached_sources[module.name] if cached_sources?
            if cached_module?
                cached_module.mtime or=0
                adapter.last_modified (err, adapter_mtime) -> # if need to recompile module
                    if module.need_to_recompile cached_module, adapter_mtime
                        message = "Module #{module.name} was changed, harvesting ..."
                        harvest_module adapter, module, ctx, message, module_cb
                    else
                        module_cb CB_SUCCESS, module
            else
                message = "Harvesting module #{module.name} ..."
                harvest_module adapter, module, ctx, message, module_cb
        else
            message = "Forced harvesting #{module.name} ..."
            harvest_module adapter, module, ctx, message, module_cb


# ====================================================================================
init_build_sequence = (ctx, adapters_path, adapters_fn, init_cb) ->
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
            cb undefined, {build_deps}

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
                    (results = results.reduce (a, b) -> extend a, b)
                    results.modules = get_modules results.recipe
                    (err = "No modules found in recipe") unless results.modules.length

                init_cb err, results
        )


run_build_sequence = (ctx, sequence_cb) ->
    init_build_sequence ctx, null, null, (err, results) ->
        (return sequence_cb err) if err
        # TODO: add modules existance check to tests
        {cache, cached_sources, build_deps, recipe, adapters, modules} = results

        _modules_iterator = partial(process_module,
                                    adapters, cached_sources, build_deps, ctx)

        async.map modules, _modules_iterator, (err, processed_modules) ->
            (return sequence_cb err) if err

            changed_modules = processed_modules.filter (m) -> m.has_sources()

            unless changed_modules.length
                ctx.fb.shout "No module was changed, skip build ..."
                return (sequence_cb CB_SUCCESS)

            _bundles_iterator = partial(process_bundle, processed_modules, cached_sources, ctx)

            async.map (get_bundles recipe), _bundles_iterator, (err, proc_bundles) ->
                (return sequence_cb err) if err

                bundles = proc_bundles.filter (b) -> b?

                if bundles.length
                    bundle_names = bundles.map (b) -> b.name
                    ctx.fb.say "Bundles [#{bundle_names}] was build successfully"
                    save_results changed_modules, bundles, cache, cached_sources, ctx, sequence_cb
                else
                    ctx.fb.shout "No changes, skip rebuild"
                    sequence_cb err, result


module.exports = {run_build_sequence, init_build_sequence}