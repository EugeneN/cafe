{read_recipe, get_modules} = require './recipe_parser'
get_adaptors = require '../adaptor'
{extend} = require '../utils'
{CB_SUCCESS, RECIPE} = require '../../defs'
{get_cache_mtime_async} = require '../modules_cache'


process_bundle = (modules, bundle) ->


process_module = (adapters, ctx, module, module_cb) ->
    _adapter_ctx = extend ctx, {module}

    _adapter_match = (adapter, cb) ->
        adapter.match.async _adapter_ctx, (err, match) -> cb match

    async.detect adapters, _adapter_match, (err, adapter) ->
        adapter = adapter.make_adaptor _adapter_ctx # TODO: ugly....

        get_cache_mtime_async module, (err, cache_mtime) ->
            adapter.last_modified (err, adapter_mtime) -> # if need to recompile module
                if adapter_mtime >= cache_mtime
                    ctx.fb.say "Harvesting module #{module.path}"
                    adapter.harvest (err, sources) ->
                        module.set_sources sources
                        module_cb CB_SUCCESS, module
                else
                    module_cb CB_SUCCESS, module


run_build_sequence = (ctx, sequence_cb) ->
    recipe_path = path.resolve ctx.own_args.app_root, (ctx.own_args.formula or RECIPE)
    [error, recipe] = read_recipe recipe_path
    (sequence_cb error) if error
    adaptors = get_adaptors() # TODO: Write test

    get_modules recipe, (err, modules) ->
        async.map modules, partial(process_module, adaptors, ctx), (err, result) ->
            #async.map (get_bundles recipe), partial(process_bundle, result), (err, result) ->
            #    sequence_cb err, result
            console.log result
            sequence_cb()

module.exports = {run_build_sequence}