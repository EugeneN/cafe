{construct_module} = require './modules'

get_bundle = (
    name="",
    modules_names=[]
    ) ->

    {name, modules_names}


construct_realm_bundle = (realm_name, data) ->
    # TODO: check inpupt datastructure, data.name must be not null
    data.map (raw_bundle) ->
        raw_bundle.name = "#{realm_name}/#{raw_bundle.name}"
        construct_bundle raw_bundle


construct_bundle = (data) ->
    modules_names = data.modules.map (m) -> construct_module(m).name
    get_bundle(name=data.name, modules_names=modules_names)

module.exports = {construct_realm_bundle, construct_bundle}

