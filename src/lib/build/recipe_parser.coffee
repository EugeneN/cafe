path = require 'path'
u = require 'underscore'

{read_json_file,flatten, extend,
is_file, toArray, partial,
read_yaml_file} = require '../../lib/utils'
{error_m, OK, ok, nok}  = require '../../lib/monads'
{toposort} = require '../../lib/build/toposort'
{construct_module, modules_equals, merge_modules} = require './modules'
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
        nok "Recipe inheritance chain to long"
    else
        ok recipe_path

read_if_is_file = (recipe_path) -> # TOTEST, TODO: separate on 2 funcs (is_file, read)
    if is_file recipe_path
        # TODO: hadle recipe validation error
        # TODO: handle yaml format sync reading
        ok (read_json_file recipe_path)
    else
        nok "Recipe file #{recipe_path} not found"


read_if_is_file.async = (recipe_path, cb) ->
    is_file.async recipe_path, (err, result) ->
        (return cb (nok "Failed to read recipe file #{err}")) if err

        if result is true
            extension = path.extname recipe_path

            reader_dict =
                ".json": read_json_file
                ".yaml": read_yaml_file

            reader = reader_dict[extension]

            unless reader?
                cb (nok "Unknown recipe format file #{recipe_path}") # TOTEST

            reader.async recipe_path, (err, result) ->
                if err
                    (return cb (nok "Failded to read recipe file #{recipe_path} #{err}"))
                cb (ok result)
        else
            cb (nok "Recipe file #{recipe_path} is not found")


check_for_inheritance = (level, recipe_path, read_recipe_fn, recipe) ->
    if recipe?.abstract?.extends
        base_recipe_path = (path.resolve (path.dirname recipe_path),
                                         recipe.abstract.extends)

        unless base_recipe_path is recipe_path
            [error, base_recipe] = (read_recipe_fn base_recipe_path, level+1)
            if error
                nok error 
            else 
                new_recipe = u.clone base_recipe
                new_recipe.opts = u.extend((base_recipe.opts or {}), (recipe.opts or {}))
                new_recipe.modules = merge_modules base_recipe.modules, recipe.modules
                ok new_recipe
        else
            nok "Recipe #{recipe_path} can not inherit from itself"
    else
        ok recipe


check_for_inheritance.async = (level, recipe_path, read_recipe_fn, recipe, cb) ->
    if recipe?.abstract?.extends
        base_recipe_path = (path.resolve (path.dirname recipe_path), recipe.abstract.extends)
        unless base_recipe_path is recipe_path
            read_recipe_fn base_recipe_path, level+1, ([err, base_recipe]) ->
                if err
                    cb (nok err)
                else
                    new_recipe = u.clone base_recipe
                    new_recipe.opts = u.extend((base_recipe.opts or {}), (recipe.opts or {}))
                    new_recipe.modules = merge_modules base_recipe.modules, recipe.modules
                    cb (ok new_recipe)
        else
            cb (nok "Recipe #{recipe_path} can not inherit from itself")
    else
        cb (ok recipe)


read_recipe = (recipe_path, level=0) ->
    lifted_handlers_chain = [
        partial chain_check, level
        read_if_is_file
        partial check_for_inheritance, level, recipe_path, read_recipe
    ]

    domonad error_m(), lifted_handlers_chain, recipe_path


read_recipe.async = (recipe_path, level=0, cb) -> # TOTEST !!!
    worker_monad = cont_t error_m()

    lifted_handlers_chain = [
        lift_sync 2, (partial chain_check, level)
        lift_async 2, read_if_is_file.async
        lift_async 5, (partial check_for_inheritance.async, level, recipe_path, read_recipe.async)
    ]

    (domonad worker_monad, lifted_handlers_chain, recipe_path) cb

get_recipe = (recipe_path) -> throw "not implemented"

get_recipe.async = (recipe_path, cb) ->
    _m_read_recipe = (recipe_path, read_cb) -> read_recipe.async recipe_path, 0, read_cb

    _m_check_recipe_internal_structure = (recipe, s_cb) ->
        # This validation must be legal also in legacy versions
        unless recipe.abstract?.api_version?
            return s_cb nok "api version section is missing in recipe"
        
        s_cb ok recipe

    seq = [
        lift_async(2, _m_read_recipe)
        lift_async(2, _m_check_recipe_internal_structure)
    ]

    (domonad (cont_t error_m()), seq, recipe_path) cb

#-----------------------------------
# Modules parsing sequence functions
#-----------------------------------
get_raw_modules = (recipe) ->
    """ Parse all modules from recipe."""
    if recipe.modules?
        ok recipe.modules
    else
        nok "Recipe has no modules section"


construct_modules = (modules) ->
    err = null

    modules = modules.map (m) ->
        [err, parsed, module] = construct_module m

        unless parsed is true
            err or= "Failed to parse module definition #{module}"
        else
            module
            
    if err then (nok err) else (ok modules)


fill_modules_deps = (recipe, modules) ->
    if recipe.deps?
        for m_name, prop_val of recipe.deps
            modules = modules.map (m) ->
                if m.name is m_name
                    m.deps = toArray m.deps
                    m.deps.push p for p in prop_val
                m
    ok modules


check_deps_names_exists = (modules) ->
    modules_names = modules.map (m) -> m.name
    for module in modules
        for dep in module.deps
            unless dep in modules_names
                return (nok "Dependency module name #{dep} of module #{module.name} was not found")
    ok modules


# TODO: make async
get_modules = (recipe) ->
    seq = [
        get_raw_modules
        construct_modules
        partial fill_modules_deps, recipe
        check_deps_names_exists
    ]

    (domonad error_m(), seq, recipe)


get_modules_and_bundles_for_sequence = (recipe, parse_cb) ->
    """
    filters parsed modules from recipe that must take part in
    build sequence.
    """
    
    unique_reducer = (a, b) -> if b in a then a else a.concat b

    _m_get_bundles = (recipe) ->     # TODO, handle exceptions
        ok [get_bundles recipe]

    _m_get_modules = (recipe, [bundles]) ->
        [err, modules] = get_modules recipe
        [err, [modules, bundles]]

    _m_construct_modules = ([modules, bundles]) ->
        unless bundles.length
            return ["No bundles found in recipe", null]

        modules_in_bundles_names = flatten(bundles.map((b) -> b.modules_names))
        modules_in_bundles = modules.filter (m) -> m.name in modules_in_bundles_names

        deps_of_modules_in_bundles = flatten(modules.map (m) -> m.deps).reduce unique_reducer, []

        modules_from_deps = modules.filter (m) -> # Include modules from deps
            (m.name in deps_of_modules_in_bundles) and (m.name not in modules_in_bundles_names)

        modules = modules_in_bundles.concat modules_from_deps

        ok [modules, bundles]

    _m_construct_bundles = ([modules, bundles]) ->
        _parse_bundle_modules = (module_name, collected_deps, modules, bundle) ->

            _module = u.find modules, (m) -> m.name is module_name

            unless _module
                throw "Unregistered module #{module_name} from bundle #{bundle.name}"

            _module_deps_names = _module.deps.filter (name) -> name not in collected_deps
            result_modules_names = (collected_deps.concat _module_deps_names).reduce unique_reducer, []

            if _module_deps_names.length
                reducer = (a, b) -> flatten(_parse_bundle_modules b, a, modules, bundle)

                inner_deps = flatten(_module_deps_names.reduce reducer, result_modules_names)
                if inner_deps.length
                    result_modules_names = (result_modules_names.concat inner_deps).reduce unique_reducer, []

            result_modules_names

        try # TODO: remove ugly try-catch ...
            bundles = bundles.map (bundle) ->
                deps_mods = bundle.modules_names.map (name) ->
                    _parse_bundle_modules name, bundle.modules_names, modules, bundle

                _modules_names = flatten(deps_mods).reduce unique_reducer, []
                _resolved_modules = _modules_names.map (_name) -> u.find modules, (m) ->m.name is _name

                try
                    _sorted_modules = toposort _resolved_modules
                catch ex
                    throw "Failed to resolve dependencies in bundle #{bundle.name} #{ex}"

                bundle.modules_names = _sorted_modules.map (m) -> m.name
                bundle
        catch ex
            return (nok ex)

        ok [modules, bundles]

    _m_process_realms = (recipe, [modules, bundles]) ->
        unless recipe.realms?
            ok [modules, bundles]
        else
            _realms = ([name, _bundles] for name, _bundles of recipe.realms)

            for [realm_name, realm_bundles] in _realms
                _realm_bundles = realm_bundles.map((_bundle) -> u.find bundles, (b) ->
                    b.name is "#{realm_name}/#{_bundle.name}")

                realm_modules_reducer = (included_modules, b1) ->
                    b1.modules_names = b1.modules_names.filter (m_name) -> m_name not in included_modules
                    included_modules.concat b1.modules_names

                _realm_bundles.reduce realm_modules_reducer, []
                
            ok [modules, bundles]

    _m_skip_modules_that_are_not_in_bundles = ([modules, bundles]) ->
        bundles_modules_names = flatten(bundles.map((b) -> b.modules_names))
        modules = modules.filter (m) -> m.name in bundles_modules_names
        ok [modules, bundles]

    seq = [
        _m_get_bundles
        partial _m_get_modules, recipe
        _m_construct_modules
        _m_construct_bundles
        partial _m_process_realms, recipe
        _m_skip_modules_that_are_not_in_bundles
    ]

    parse_cb (domonad error_m(), seq, recipe)


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
    get_recipe
    get_raw_modules
    read_recipe
    construct_modules
    fill_modules_deps
    get_modules
    get_bundles
    read_if_is_file
    get_modules_and_bundles_for_sequence
    check_deps_names_exists
}
