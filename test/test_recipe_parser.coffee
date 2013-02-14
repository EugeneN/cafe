path = require 'path'
u = require 'underscore'
{read_recipe
get_raw_modules
get_modules_async
get_bundles
remove_modules_duplicates
construct_modules
fill_modules_deps} = require '../src/lib/build/recipe_parser'

fixtures_path = path.resolve './test/fixtures/recipe_parser'

recipe1_path = path.join fixtures_path, 'recipe.json'
recipe2_path = path.join fixtures_path, 'recipe2.json'
recipe3_path = path.join fixtures_path, 'recipe3.json'
recipe_modules_parse_path = path.join fixtures_path, 'modules_parse_recipe.json'
recipe_bundles_parse_path = path.join fixtures_path, 'bundles_parse_recipe.json'


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


test_recipe_modules_read = (test) ->
    # TODO add test when recipe format is invalid.
    [error, recipe] = read_recipe recipe1_path
    modules = get_raw_modules recipe
    test.ok modules.length is 8, "Expected 8 modules found #{modules.length}"
    [error, recipe] = read_recipe recipe_modules_parse_path
    raw_modules = get_raw_modules recipe
    parsed_modules = construct_modules raw_modules
    result_modules = remove_modules_duplicates parsed_modules
    test.ok(result_modules.length is 6,
        "Expected 6 unique module - recieved #{result_modules.length}")
    test.done()


exports.test_recipe_modules_metadata_parse = (test) ->
    [error, recipe] = read_recipe recipe_modules_parse_path
    get_modules_async recipe, (modules) ->
        module1 = (modules.filter (m) -> m.name is "module1")[0]
        test.ok "module5" in module1.deps, "module5 must be in module1 deps"
        test.ok modules.length is 6, "Expected 6 modules - #{modules.length} recieved"
        test.done()


exports.test_recipe_bundles_parse = (test) ->
    [error, recipe] = read_recipe recipe_bundles_parse_path
    bundles_names = (get_bundles recipe).map (b) -> b.name
    result_realms = ["realm1/bundle1", "realm2/bundle1", "realm1/bundle2", "realm2/bundle2"]
    result_realms.map (b) ->
        test.ok((b in bundles_names), "#{b} must be in result #{bundles_names}")

    test.done()




