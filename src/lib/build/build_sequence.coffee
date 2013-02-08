{read_recipe, get_modules} = require './recipe_parser'

process_module = (module) ->
    # check if changed
    # compile if need


get_modules_to_rebuild = (modules) ->
    # return

module_is_outdated = (module) ->


process_bundle = (modules, bundle) ->


process_module = (module, cb) ->
    if module_is_outdated m
        m.sources = compile m, (err, resutl) ->
            cb err, result
    else
        cb null, m


run_build_sequence = (recipe_path, sequence_cb) ->
    [error, recipe] = read_recipe recipe_path
    (sequence_cb error) if error

    get_modules recipe, (err, modules) ->
        async.map modules, process_module, (err, result) ->
            async.map (get_bundles recipe), partial(process_bundle, result), (err, result) ->
                sequence_cb err, result
