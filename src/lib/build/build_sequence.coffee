async = require 'async'
path = require 'path'
{read_recipe, get_modules} = require './recipe_parser'
get_adaptors = require '../adaptor'
{extend, partial, get_cafe_dir} = require '../utils'
{CB_SUCCESS, RECIPE} = require '../../defs'
{get_modules_cache} = require '../modules_cache'
{wrap_bundle, wrap_modules, wrap_module} = require 'wrapper-commonjs'

# ======================== BUNDLES PROCESSING ======================================================
process_bundle = (modules, bundles, bundle_cb) ->
    # Check what bundles wasn't been changed
    was_modified = (_modules, _bundle) ->

    check_unchanged = (_modules, _bundles, cb) ->
        async.filter _bundles, partial(was_modified, _modules), (err, result) ->
            # Handle when no module in bundle was changed ...


# ======================== MODULES PROCESSING ======================================================
get_modules_cache_dir = (app_root) -> path.resolve path.join get_cafe_dir(app_root), 'modules_cache'

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
    async.map modules, partial(process_module, adapters, ctx), (err, result) ->
        #async.map (get_bundles recipe), partial(process_bundle, result), (err, result) ->
        #    sequence_cb err, result
        #console.log ">>> result >>>", result
        #for r in result
        #    console.log "s->", r.get_sources()
        sequence_cb err

module.exports = {run_build_sequence}