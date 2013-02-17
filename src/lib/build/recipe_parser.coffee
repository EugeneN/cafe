path = require 'path'
u = require 'underscore'

{read_json_file, flatten, extend, is_file, toArray, partial} = require '../../lib/utils'
{construct_module, modules_equals} = require './modules'
{construct_realm_bundle} = require './bundles'

{
    cont_t, cont_m,
    maybe_t, maybe_m,
    logger_t, logger_m,
    domonad, is_null,
    lift_sync, lift_async
} = require 'libmonad'

RECIPE = 'recipe.json'

OK = undefined
error_m = -> # TODO: move this to libmonad
    is_error = ([err, val]) -> err isnt OK

    result: (v) -> [OK, v]

    bind: (mv, f) ->
        if (is_error mv) then mv else (f mv[1])

#-----------------------------------
# Recipe parsing sequence functions
#-----------------------------------
chain_check = (level, recipe_path) ->
    if level > 3
        ["Recipe inheritance chain to long", undefined]
    else
        [OK, recipe_path]

read_if_is_file = (recipe_path) -> # # TOTEST
    if is_file recipe_path
        # TODO: hadle recipe validation error
        [OK, (read_json_file recipe_path)]
    else
        ["Recipe file #{recipe_path} is not found", undefined]


read_if_is_file.async = (recipe_path, cb) -> # TOTEST
    is_file.async recipe_path, (err, result) ->
        (return cb ["Failed to read recipe file #{err}", undefined]) if err
        if result is true
            read_json_file.async recipe_path, (err, result) ->
                (return cb [err, undefined]) if err
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
    modules = flatten((v for k,v of recipe.realms)).map((b) -> b.modules).reduce((a, b) -> a.concat b)
    if recipe.modules?
        (modules.concat recipe.modules)
    else
        modules


construct_modules = (modules) ->
    modules.map (m) -> construct_module m


remove_modules_duplicates = (modules) ->
    reduce_func =(a, b) ->
        a.push b unless (u.any a, (m) -> modules_equals m, b)
        a

    modules.reduce reduce_func, []


fill_modules_deps = (recipe, modules) ->
    if recipe.deps?
        for m_name, prop_val of recipe.deps
            modules = modules.map (m) ->
                if m.name is m_name
                    m.deps = toArray m.deps
                    m.deps.push p for p in prop_val
                m
    modules


get_modules = (recipe) ->
    seq = [
        get_raw_modules
        construct_modules
        remove_modules_duplicates
        partial(fill_modules_deps, recipe)
    ]

    work_monad = maybe_m {is_error: is_null}
    (domonad work_monad, seq, recipe)


#-----------------------------------
# Bundles parsing sequence functions
#-----------------------------------
get_bundles = (recipe) ->
    # FIXME: returns invalid bundle names if called twice.
    flatten ((construct_realm_bundle realm, data) for realm, data of recipe.realms)


module.exports = {
    get_raw_modules
    read_recipe
    remove_modules_duplicates
    construct_modules
    fill_modules_deps
    get_modules
    get_bundles
    read_if_is_file
}