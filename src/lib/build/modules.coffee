get_module = (
    path=""
    name=""
    deps=[]
    type="commonjs"
    location="fs"
    ) ->

    _sources = ""
    set_sources = (sources) -> _sources = sources
    has_sources = () -> _sources isnt ""
    get_sources = -> _sources

    {name, path, deps, type, location, set_sources, get_sources}


modules_equals = (m1, m2) -> m1.name is m2.name


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


module.exports = {construct_module, get_module, modules_equals}
