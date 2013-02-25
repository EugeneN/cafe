{construct_module} = require './modules'

get_bundle = (
    name="",
    modules_names=[]
    ) ->

    _modules = null
    set_modules = (modules) -> _modules = modules.map (m) -> m.serrialize_meta()
    get_modules = () -> _modules
    has_modules = () -> _modules?
    serrialize = () -> {name:name, modules:get_modules()}

    {
    name
    modules_names
    set_modules
    get_modules
    has_modules
    serrialize
    }


construct_realm_bundle = (realm_name, data) ->
    # TODO: check inpupt datastructure, data.name must be not null
    data.map (raw_bundle) ->
        raw_bundle.name = "#{realm_name}/#{raw_bundle.name}"
        construct_bundle raw_bundle


construct_bundle = (data, name) ->
    name or= data.name
    modules_names = data.modules
    get_bundle(name, modules_names=modules_names)

module.exports = {construct_realm_bundle, construct_bundle}

