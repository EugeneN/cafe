path = require 'path'
u = require 'underscore'

{read_json_file, flatten, extend, is_file, toArray, partial} = require '../../lib/utils'
{domonad, error_monad} = require '../../lib/libmonad'
{construct_module, modules_equals} = require './modules'
{waterfall_lift} = require '../../lib/async_tools'
{construct_realm_bundle} = require './bundles'

RECIPE = 'recipe.json'


#-----------------------------------
# Recipe parsing sequence functions
#-----------------------------------
read_recipe = (recipe_path, level=0) ->
    chain_check = (recipe_path) ->
        if level > 3
            ["Recipe inheritance chain to long", undefined]
        else
            [undefined, recipe_path]

    read_if_is_file = (recipe_path) ->
        if is_file recipe_path
            # TODO: hadle recipe validation error
            [undefined, (read_json_file recipe_path)]
        else
            ["Recipe file #{recipe_path} is not found", undefined]

    check_for_inheritance = (recipe) ->
        if recipe?.abstract?.extends
            base_recipe_path = (path.resolve (path.dirname recipe_path),
                                             recipe.abstract.extends)

            unless base_recipe_path is recipe_path
                [error, base_recipe] = (read_recipe base_recipe_path, level+1)
                recipe = (extend base_recipe, recipe)
            else
                error = "Recipe #{recipe_path} can not inherit from itself"
        [error, recipe]

    _get_recipe = domonad(error_monad
                          [chain_check, read_if_is_file, check_for_inheritance])

    _get_recipe recipe_path


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


get_modules_async = (recipe, ret_cb) ->
    seq = [
        get_raw_modules
        construct_modules
        remove_modules_duplicates
        partial(fill_modules_deps, recipe)
    ]

    waterfall_lift seq, recipe, ret_cb


#-----------------------------------
# Bundles parsing sequence functions
#-----------------------------------
get_bundles = (recipe) ->
    flatten ((construct_realm_bundle realm, data) for realm, data of recipe.realms)


module.exports = {
    get_raw_modules
    read_recipe
    remove_modules_duplicates
    construct_modules
    fill_modules_deps
    get_modules_async
    get_bundles
}