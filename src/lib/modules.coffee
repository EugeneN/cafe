get_module = (
    path=""
    name=""
    deps=[]
    type="commonjs"
    location="fs"
    ) ->

    {name, path, deps, type, location}


construct_module = (meta) ->
    if (typeof meta) is "string"
        get_module(alias=meta, path=meta)

    else if Array.isArray(meta)
        [path, type, location, deps, location, name] = meta
        throw "at least name or path must be set" unless (name? or path?)
        name or=path
        path or=name
        get_module(name=name, path=path, deps=deps, type=type, location=location)

    else
        {name, path, deps, type, location} = meta
        throw "at least name or path must be set" unless (name? or path?)
        name or=path
        path or=name
        get_module(name=name, path=path, deps=deps, type=type, location=location)


module.exports = {construct_module, get_module}
