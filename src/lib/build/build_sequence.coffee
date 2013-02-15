async = require 'async'
u = require 'underscore'
path = require 'path'
{read_recipe, get_modules, get_bundles} = require './recipe_parser'
get_adaptors = require '../adaptor'
{extend, partial, get_cafe_dir} = require '../utils'
{CB_SUCCESS, RECIPE} = require '../../defs'
{get_modules_cache} = require '../modules_cache'
{wrap_bundle, wrap_modules, wrap_module} = require 'wrapper-commonjs'

get_modules_cache_dir = (app_root) -> path.resolve path.join get_cafe_dir(app_root), 'modules_cache'

# ======================== BUNDLES PROCESSING ======================================================
process_bundle = (modules, bundle, bundle_cb) ->
    # select modules for bundle
    modules = modules.filter (m) -> m.name in bundle.modules_names

    # Check what bundles wasn been recompiled.
    was_compiled = (_modules, _bundle) ->
        # TODO: compare with build_deps
        u.some _bundle.modules_names, (m_name) ->
            m = u.find _modules, (mod) -> mod.name is m_name
            m.has_sources()? # if atleast one module was compiled

    # check if some modules metadata was changed.
    meta_changed = () -> false

    fill_sources = (m, cb) -> cb null, m.get_sources() # temporary mock.

    if was_compiled(modules, bundle) or meta_changed(modules, bundle)
        # TODO: make modules TOPOSORT
        async.map modules, fill_sources, (err, bundle_sources) ->
            # Post processing
            bundle_sources = wrap_bundle bundle_sources.join '\n'
            # Post processing ... minify e.t.c.
            bundle_cb CB_SUCCESS, [bundle, bundle_sources]
    else
        bundle_cb CB_SUCCESS, null


# ======================== MODULES PROCESSING ======================================================
harvest_module = (adapter, module, ctx, message, cb) ->
    message or= "Harvesting module #{module.path}"
    ctx.fb.say message
    adapter.harvest (err, sources) ->
        # TODO check if err
        # TODO: post compile module processing sequence
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
run_build_sequence = (ctx, sequence_cb) ->
    # ----------------------------Initialization--------------------------------------
    recipe_path = path.resolve ctx.own_args.app_root, (ctx.own_args.formula or RECIPE)
    [error, recipe] = read_recipe recipe_path
    (sequence_cb error) if error
    adapters = get_adaptors() # TODO: Write test
    modules = get_modules recipe
    sequence_cb "No modules found in recipe #{recipe_path}" unless modules?
    # --------------------------------------------------------------------------------

    #----------------------- Process sequence ----------------------------------------
    async.map modules, partial(process_module, adapters, ctx), (err, processed_modules) ->
        async.map (get_bundles recipe), partial(process_bundle, processed_modules), (err, result) ->
            compiled_bundle_names = result.filter(([bundle, sources]) -> sources?).map ([bundle, sources]) -> bundle.name
            if compiled_bundle_names.length
                ctx.fb.say "Bundles [#{compiled_bundle_names}] was build successfully"
            else
                ctx.fb.shout "No changes, skip rebuild"
            sequence_cb err, result

module.exports = {run_build_sequence}