path = require 'path'
u = require 'underscore'

{read_json_file,flatten, extend,
is_file, toArray, partial,
read_yaml_file} = require '../../lib/utils'
{error_m, OK}  = require '../../lib/monads'

{construct_module, modules_equals} = require './modules'
{construct_realm_bundle, construct_bundle} = require './bundles'

{
    cont_t, cont_m,
    maybe_t, maybe_m,
    logger_t, logger_m,
    domonad, is_null
    lift_sync, lift_async
} = require 'libmonad'

RECIPE = 'recipe.json'

#-----------------------------------
# Recipe parsing sequence functions
#-----------------------------------
chain_check = (level, recipe_path) ->
    if level > 3
        ["Recipe inheritance chain to long", undefined]
    else
        [OK, recipe_path]

read_if_is_file = (recipe_path) -> # TOTEST, TODO: separate on 2 funcs (is_file, read)
    if is_file recipe_path
        # TODO: hadle recipe validation error
        [OK, (read_json_file recipe_path)]
    else
        ["Recipe file #{recipe_path} is not found", undefined]


read_if_is_file.async = (recipe_path, cb) ->
    is_file.async recipe_path, (err, result) ->
        (return cb ["Failed to read recipe file #{err}", undefined]) if err

        if result is true
            extension = path.extname recipe_path

            reader_dict =
                ".json": read_json_file
                ".yaml": read_yaml_file

            reader = reader_dict[extension]

            unless reader?
                cb ["Unknown recipe format file #{recipe_path}", null] # TOTEST

            reader.async recipe_path, (err, result) ->
                if err
                    err = "Failded to read recipe file #{recipe_path} #{err}"
                    (return cb [err, undefined])

                cb [OK, result]
        else
            cb ["Recipe file #{recipe_path} is not found", undefined]


check_for_inheritance = (level, recipe_path, read_recipe_fn, recipe) ->
    if recipe?.abstract?.extends
        base_recipe_path = (path.resolve (path.dirname recipe_path),
                                         recipe.abstract.extends)

        unless base_recipe_path is recipe_path
            [error, base_recipe] = (read_recipe_fn base_recipe_path, level+1)
            recipe = (extend base_recipe, recipe)
        else
            error = "Recipe #{recipe_path} can not inherit from itself"
    [error, recipe]


check_for_inheritance.async = (level, recipe_path, read_recipe_fn, recipe, cb) ->
    if recipe?.abstract?.extends
        base_recipe_path = (path.resolve (path.dirname recipe_path),
                                         recipe.abstract.extends)

        unless base_recipe_path is recipe_path
            recursive_cb = ([error, base_recipe]) ->
                recipe = (extend base_recipe, recipe)
                cb [error, recipe]
            (read_recipe_fn base_recipe_path, level+1, recursive_cb)

        else
            error = "Recipe #{recipe_path} can not inherit from itself"
    cb [error, recipe]


read_recipe = (recipe_path, level=0) ->
    lifted_handlers_chain = [
        partial(chain_check, level)
        read_if_is_file
        partial(check_for_inheritance, level, recipe_path, read_recipe)
    ]

    domonad error_m(), lifted_handlers_chain, recipe_path


read_recipe.async = (recipe_path, level=0, cb) ->
    worker_monad = cont_t error_m()

    lifted_handlers_chain = [
        lift_sync(2, partial(chain_check, level))
        lift_async(2, read_if_is_file.async)
        lift_async(5, partial(check_for_inheritance.async, level, recipe_path, read_recipe))
    ]

    (domonad worker_monad, lifted_handlers_chain, recipe_path) cb


#-----------------------------------
# Modules parsing sequence functions
#-----------------------------------
get_raw_modules = (recipe) ->
    """ Parse all modules from recipe."""
    if recipe.modules?
        [null, recipe.modules]
    else
        ["Recipe has no modules section", null]


construct_modules = (modules) ->
    err = null

    modules = modules.map (m) ->
        [err, parsed, module] = construct_module m

        unless parsed is true
            err or= "Failed to parse module definition #{module}"
        else
            module

    [err, modules]


fill_modules_deps = (recipe, modules) ->
    if recipe.deps?
        for m_name, prop_val of recipe.deps
            modules = modules.map (m) ->
                if m.name is m_name
                    m.deps = toArray m.deps
                    m.deps.push p for p in prop_val
                m
    [null, modules]


get_modules = (recipe) ->
    seq = [
        get_raw_modules
        construct_modules
        partial(fill_modules_deps, recipe)
    ]

    (domonad error_m(), seq, recipe)


#-----------------------------------
# Bundles parsing sequence functions
#-----------------------------------
get_bundles = (recipe) ->
    bundles = if recipe.bundles?
        (for bundle_name, bundle_data of recipe.bundles
            (construct_bundle bundle_data, bundle_name))
    else
        []

    realm_bundles = if recipe.realms?
        flatten ((construct_realm_bundle realm, data) for realm, data of recipe.realms)
    else
        []

        (bundles.concat realm_bundles).filter (b) -> b?


module.exports = {
    get_raw_modules
    read_recipe
    construct_modules
    fill_modules_deps
    get_modules
    get_bundles
    read_if_is_file
}