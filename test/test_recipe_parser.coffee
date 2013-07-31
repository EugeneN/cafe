path = require 'path'
{read_recipe
get_recipe
get_raw_modules
get_modules
get_bundles
remove_modules_duplicates
construct_modules
get_modules_and_bundles_for_sequence
fill_modules_deps
check_deps_names_exists} = require '../src/lib/build/recipe_parser'

fixtures_path = path.resolve './test/fixtures/recipe_parser'

recipe1_path = path.join fixtures_path, 'recipe.json'
recipe2_path = path.join fixtures_path, 'recipe2.json'
recipe3_path = path.join fixtures_path, 'recipe3.json'
recipe_modules_parse_path = path.join fixtures_path, 'modules_parse_recipe.json'
recipe_realm_bundles_parse_path = path.join fixtures_path, 'bundles_realm_parse_recipe.json'
recipe_bundles_parse_path = path.join fixtures_path, 'bundles_parse_recipe.json'
recipe_yaml_path = path.join fixtures_path, "recipe.yaml"
recipe_sequence_parse = path.join fixtures_path, "recipe_sequence.yaml"
recipe_deps_exists = path.join fixtures_path, "recipe_deps_existance.yaml"
recipe_without_modules = path.join fixtures_path, "recipe_without_modules.yaml"
recipe_abstract_check = path.join fixtures_path, "recipe_abstract_section.yaml"
recipe_bundle_modules_empty = path.join fixtures_path, "bundle_modules_empty.yaml"


exports.test_recipe_read_basic_validation = (test) ->
    [error, recipe] = read_recipe(path.join fixtures_path, 'recipe23232.json')
    test.ok (error), "Error does'nt occured while file is not exists"
    [error, recipe] = read_recipe recipe1_path
    test.ok recipe, "Returned empty recipe while read existent file"
    read_recipe.async recipe1_path, 0, ([error, recipe]) ->
        test.ok error is undefined, "Valid recipe returned an error #{error}"
        test.ok recipe?, "Recipe object was not returned"
    read_recipe.async 'recipe23232.json', 0, ([error, recipe]) ->
        test.ok error?, "Invalid recipe returned success #{error}"
        test.ok !recipe?, "Invalid recipe returned recipe object"
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
    # TODO add test when recipe format is invalid.
    [error, recipe] = read_recipe recipe1_path
    [err, modules] = get_raw_modules recipe
    test.ok modules.length is 3, "Expected 3 modules found #{modules.length}"
    test.done()


exports.test_recipe_modules_metadata_parse = (test) ->
    [error, recipe] = read_recipe recipe_modules_parse_path
    [err, modules] = get_modules recipe
    module1 = (modules.filter (m) -> m.name is "module1")[0]
    test.ok "module5" in module1.deps, "module5 must be in module1 deps"
    test.ok modules.length is 4, "Expected 4 modules - #{modules.length} recieved"
    test.done()


exports.test_recipe_bundles_realms_parse = (test) ->
    [error, recipe] = read_recipe recipe_realm_bundles_parse_path
    bundles_names = (get_bundles recipe).map (b) -> b.name
    result_realms = ["realm1/bundle1", "realm2/bundle1", "realm1/bundle2", "realm2/bundle2"]
    result_realms.map (b) ->
        test.ok((b in bundles_names), "#{b} must be in result #{bundles_names}")

    test.done()


exports.test_recipe_bundles_parse = (test) ->
    [error, recipe] = read_recipe recipe_bundles_parse_path
    bundles = (get_bundles recipe)
    bundles_names = bundles.map (b) -> b.name
    result_bundles = ["bundle1", "bundle2"]
    result_bundles.map (b) ->
        test.ok((b in bundles_names), "#{b} must be in result #{bundles_names}")

    test.done()


exports.test_recipe_yaml_reader = (test) ->
    read_recipe.async recipe_yaml_path, 0, ([error, recipe]) ->
        test.ok recipe.abstract, "Recipe object was not parsed"
        test.ok !(error?), "Some error occured while reading valid yaml file #{error}"
        test.done()


exports.test_get_modules_and_bundles_for_sequence = (test) ->
    read_recipe.async recipe_sequence_parse, 0, ([error, recipe]) ->
        get_modules_and_bundles_for_sequence recipe, ([err, [modules, bundles]]) ->
            [bundle1, bundle2] = bundles
            [jquery_module] = modules.filter (m) -> m.name is "jquery"

            unique_reducer = (a, b) -> if b in a then a else a.concat b
            unique_names = bundle1.modules_names.reduce unique_reducer, []

            test.ok(
                bundle1.modules_names.length is unique_names.length
                "Bundle1 must have only unique module names"
            )

            test.ok(
                jquery_module?
                "Module jquery must be in result modules, because plain_coffee and test1 depends on it"
            )
            test.ok(
                "jquery" in bundle1.modules_names
                "Module jquery must be in bundle1, because plain_coffee and test1 depends on it #{bundle1.modules_names}"
            )

            test.ok(
                "jquery" in bundle2.modules_names
                "Module jquery must be in bundle2, because plain_coffee and test1 depends on it #{bundle2.modules_names}"
            )

            test.ok(
                "test1" in bundle2.modules_names
                "Module test1 must be in bundle2, because test2 depends on it #{bundle2.modules_names}"
            )

            test.ok(
                "skipped" not in modules.map (m) -> m.name
                "skipped module must not be included in result module, because it doesn't belongs to any bundle"
                )

            test.done()


exports.test_bundle_modules_empty = (test) ->
    get_recipe.async recipe_bundle_modules_empty, ([error, recipe]) ->
        get_modules_and_bundles_for_sequence recipe, ([err, [modules, bundles]]) ->
            test.ok(
                modules.length is 0
                "Bunle has no modules included, so no modules must be parsed for sequence")
            test.done()


exports.test_check_deps_existance  = (test) ->
    read_recipe.async recipe_deps_exists, 0, ([error, recipe]) ->
        [err, modules] = get_modules recipe

        test.ok(
            err?
            "Error didn't occured while not existent module jquer was set as dependency for module plain_coffee"
        )

        test.done()


#exports.test_check_if_modules_in_recipe = (test) ->
#    get_recipe.async recipe_without_modules, ([error, recipe]) ->
#        test.ok (error?), "Recipe without modules can't pass"
#        test.done()

exports.test_check_abstract_section = (test) ->
    get_recipe.async recipe_abstract_check, ([error, recipe]) ->
        test.ok (error?), "Recipe without abstract section can't pass"
        test.done()

