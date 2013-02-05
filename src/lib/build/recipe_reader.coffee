path = require 'path'
{read_json_file, extend, is_file} = require '../../lib/utils'
{domonad, error_monad} = require '../../lib/libmonad'
RECIPE = 'recipe.json'

read_recipe = (recipe_path, level=0) ->
    chain_check = (recipe_path) ->
        if level > 3
            ["Recipe inheritance chain to long", undefined]
        else
            [undefined, recipe_path]

    read_if_is_file = (recipe_path) ->
        if is_file recipe_path
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

    _get_recipe = domonad(
                    error_monad [chain_check, read_if_is_file, check_for_inheritance])

    _get_recipe recipe_path

"""
read_recipe = (recipe_path, level=0) ->
    if level > 3
        scream "Recipe inheritance chain to long"
        undefined

    else if is_file recipe_path
        recipe = read_json_file recipe_path
        if recipe?.abstract?.extends
            base_recipe_path = (path.resolve (path.dirname recipe_path),
                                             recipe.abstract.extends)

            unless base_recipe_path is recipe_path
                if (base_recipe = read_recipe base_recipe_path, level + 1)
                    extend base_recipe, recipe
                else
                    undefined
            else
                undefined
        else
            recipe
    else
        undefined

"""
get_modules = (recipe) ->
    recipe.modules


module.exports = {get_modules, read_recipe}
