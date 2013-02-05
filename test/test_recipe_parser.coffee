path = require 'path'
{read_recipe, get_raw_modules} = require '../src/lib/build/recipe_parser'
fixtures_path = path.resolve './test/fixtures/recipe_parser'

recipe1_path = path.join fixtures_path, 'recipe.json'
recipe2_path = path.join fixtures_path, 'recipe2.json'
recipe3_path = path.join fixtures_path, 'recipe3.json'

# Check recipe modules reader
exports.test_recipe_read_basic_validation = (test) ->
    [error, recipe] = read_recipe(path.join fixtures_path, 'recipe23232.json')
    test.ok (error), "Error does'nt occured while file is not exists"
    [error, recipe] = read_recipe recipe1_path
    test.ok recipe, "Returned empty recipe while read existent file"
    test.done()


exports.test_recipe_inheritance = (test) ->
    [error, recipe] = read_recipe recipe2_path
    test.ok (error is undefined), "some error occured while reading recipe #{error}"
    test.ok (recipe.hasOwnProperty "opts"), "recipe was not inherited properly"
    test.ok (recipe.opts.minify is true), "recipe was not inherited properly"
    [error, recipe] = read_recipe recipe3_path
    test.ok error, "Succed to read recipe that inherits from itself"
    test.done()


exports.test_recipe_modules_read = (test) ->
    [error, recipe] = read_recipe recipe1_path
    modules = get_raw_modules recipe
    test.ok modules.length is 8, "Expected 8 modules found #{modules.length}"
    test.done()

