{or_} = require '../utils'
u = require 'underscore'

get_module = (
    path=""
    name=""
    deps=[]
    type="commonjs"
    location="fs"
    ) ->

    _sources = ""
    _mtime = 0

    set_sources = (sources) ->
        _mtime = Date.now()
        _sources = sources

    copy_sources = (sources) ->
        _sources = sources

    has_sources = -> _sources isnt ""
    get_sources = -> _sources
    get_mtime = -> _mtime

    need_to_recompile = (cached_module, compared_mtime) ->
        or_(
            cached_module.type isnt type
            cached_module.mtime < compared_mtime
            cached_module.path isnt path
        )

    need_to_reorder = (module) ->
        (u.difference module.deps, deps) > 0

    serrialize_sources = ->
        {name:name, sources: get_sources(), mtime: get_mtime(), type:type, path:path}

    serrialize_meta = -> {name, path, type, location, deps}

    {
    name
    path
    deps
    type
    location
    set_sources
    has_sources
    get_sources
    serrialize_sources
    serrialize_meta
    need_to_recompile
    need_to_reorder
    copy_sources
    }


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
