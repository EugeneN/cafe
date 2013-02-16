fs = require 'fs'
async = require 'async'
u = require 'underscore'
path = require 'path'
mkdirp = require 'mkdirp'
{read_recipe, get_modules, get_bundles} = require './recipe_parser'
get_adaptors = require '../adaptor'
{extend, partial, get_cafe_dir} = require '../utils'
{CB_SUCCESS, RECIPE, BUILD_DIR, BUILD_DEPS_FN} = require '../../defs'
{get_modules_cache} = require '../modules_cache'
{wrap_bundle, wrap_modules, wrap_module} = require 'wrapper-commonjs'
CACHE_FN = 'modules.cache'

get_modules_cache_dir = (app_root) -> path.resolve path.join get_cafe_dir(app_root), 'modules_cache' #move to defs
get_build_dir = (build_root) -> path.resolve path.join build_root, BUILD_DIR

# ======================== SAVING RESULTS ==========================================================
save_results = (modules, bundles, cache, ctx, save_cb) ->
    build_dir = get_build_dir ctx.own_args.build_root

    save_build_deps = (modules, cb) ->
        serrialized_bundles = JSON.stringify((bundles.map (b) -> b.serrialize()), null, 4)
        fs.writeFile (path.join build_dir, BUILD_DEPS_FN), serrialized_bundles, (err) ->
            cb err

    async.parallel(
        [
            partial(save_build_deps, modules)
            partial(cache.save_modules_async, modules, CACHE_FN)
        ]
        save_cb
    )

# ======================== BUNDLES PROCESSING ======================================================
process_bundle = (modules, cache, ctx, bundle, bundle_cb) ->
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
    fill_sources = (m, cb) -> cb null, m # temporary mock.

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
                    bundle_cb err, [bundle, modules_with_sources]
    else
        bundle_cb CB_SUCCESS, null


# ======================== MODULES PROCESSING ======================================================
harvest_module = (adapter, module, ctx, message, cb) ->
    message or= "Harvesting module #{module.path}"
    ctx.fb.say message
    adapter.harvest (err, sources) ->
        return(cb err) if err
        # post compile module processing sequence
        module.set_sources wrap_module(sources.sources, sources.ns, sources.type)# TODO: check that sources are present
        cb err, module


process_module = (adapters, ctx, module, module_cb) ->
    _adapter_ctx = extend ctx, {module}

    _adapter_match = (adapter, cb) ->
        adapter.match.async _adapter_ctx, (err, match) -> cb match

    async.detect adapters, _adapter_match, (adapter) ->
        module_cb "No adapter found for #{module.name} module" unless adapter?
        adapter = adapter.make_adaptor _adapter_ctx # TODO: ugly....

        cache_mtime = 0 # TODO: get cache_mtime later
        unless ctx.own_args.f
            adapter.last_modified (err, adapter_mtime) -> # if need to recompile module
                if adapter_mtime >= cache_mtime
                    message = "Module #{module.name} was changed, harvesting ..."
                    harvest_module adapter, module, ctx, message, module_cb
                else
                    module_cb CB_SUCCESS, module
        else
            message = "Forced harvesting #{module.name} ..."
            harvest_module adapter, module, ctx, message, module_cb


# ====================================================================================
init_build_sequence = (ctx, init_cb) ->
    _read_recipe_async = (cb) ->
        recipe_path = path.resolve ctx.own_args.app_root, (ctx.own_args.formula or RECIPE)
        [error, recipe] = read_recipe recipe_path
        cb error, {recipe}

    _get_adapters_async = (cb) ->
        get_adapters_async (err, adapters) ->
            cb err, {adapters}

    _get_cache_modules_async = (cb) ->

    _get_build_deps_async = (cb) ->

    async.parallel(
        [
            _read_recipe_async
            _get_adapters_async
            _get_cache_modules_async
            _get_build_deps_async
        ]
        init_cb
    )



run_build_sequence = (ctx, sequence_cb) ->
    # ----------------------------Initialization--------------------------------------
    recipe_path = path.resolve ctx.own_args.app_root, (ctx.own_args.formula or RECIPE)
    [error, recipe] = read_recipe recipe_path
    return(sequence_cb error) if error
    adapters = get_adaptors() # TODO: Write test

    # read build_deps
    # read modules cache

    modules = get_modules recipe

    sequence_cb "No modules found in recipe #{recipe_path}" unless modules?
    # --------------------------------------------------------------------------------

    #----------------------- Process sequence ----------------------------------------
    get_modules_cache get_modules_cache_dir(ctx.own_args.app_root), (err, cache) ->
        (return sequence_cb err) if err

        async.map modules, partial(process_module, adapters, ctx), (err, processed_modules) ->
            async.map (get_bundles recipe), partial(process_bundle, processed_modules, cache, ctx), (err, result) ->
                (return sequence_cb err) if err

                compiled_bundle_names = result.filter(([bundle, modules]) -> modules?)\
                                              .map ([bundle, modules]) -> bundle.name

                bundles = result.map ([bundle, modules]) -> bundle

                if compiled_bundle_names.length
                    ctx.fb.say "Bundles [#{compiled_bundle_names}] was build successfully"
                    save_results modules, bundles, cache, ctx, sequence_cb
                else
                    ctx.fb.shout "No changes, skip rebuild"
                    sequence_cb err, result

module.exports = {run_build_sequence}