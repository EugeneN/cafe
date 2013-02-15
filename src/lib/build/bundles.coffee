{construct_module} = require './modules'

get_bundle = (
    name="",
    modules_names=[]
    ) ->
    _modules = null
    set_modules = (modules) -> _modules = modules
    get_modules = () -> _modules
    has_modules = () -> _modules?

    {name, modules_names, set_modules, get_modules, has_modules}


construct_realm_bundle = (realm_name, data) ->
    # TODO: check inpupt datastructure, data.name must be not null
    data.map (raw_bundle) ->
        raw_bundle.name = "#{realm_name}/#{raw_bundle.name}"
        construct_bundle raw_bundle


construct_bundle = (data) ->
    modules_names = data.modules.map (m) -> construct_module(m).name
    get_bundle(name=data.name, modules_names=modules_names)

module.exports = {construct_realm_bundle, construct_bundle}

