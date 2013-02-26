{or_} = require '../utils'
u = require 'underscore'
{skip_or_error_m, OK} = require '../monads'
{domonad} = require 'libmonad'

get_module = ({path, name, deps, type, location}) ->

    location or= "fs"
    type or= "commonjs"
    deps or= []

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


_m_check_format = (meta) ->
    """
    Checks input metadata to be an object with 1 key (module name)
    """
    unless meta instanceof Object
        return ["Wrong module format #{meta}", false, null]

    keys = Object.keys meta

    unless keys.length
        return ["Wrong module definition #{meta}", false, null]

    if keys.length > 1
        return ["Wrong module definition #{meta}", false, null]

    [OK, false, meta]


_m_parse_from_string = (meta) ->
    """
    Parses module from string value.
    """
    name = (Object.keys meta)[0]
    path = meta[name]

    if (typeof meta[name]) is "string"
        [OK, true, get_module({name, path})]
    else
        [OK, false, meta]


_m_parse_from_list = (meta) ->
    """
    Parses from list arguments.
    module_name: [path, type, deps]
    """

    name = (Object.keys meta)[0]

    if Array.isArray meta[name]
        [path, type, deps] = meta[name]
        unless path?
            ["Missing path in module definition. Module #{name}", false, null]
        else
            [OK
             true
             get_module({name, path, deps, type})]
    else

        [OK, false, meta]


_m_parse_from_dict = (meta) ->
    name = (Object.keys meta)[0]
    module = meta[name]

    unless module?
        return ["Module has wrong format #{module}", false, null]

    {path, deps, type} = module
    if path?
        [OK
         true
         get_module({name, path, deps, type})]
    else
        ["Path is not set for module #{module}", false, meta]


construct_module = (meta) ->
    seq = [
        _m_check_format
        _m_parse_from_string
        _m_parse_from_list
        _m_parse_from_dict
    ]

    domonad skip_or_error_m(), seq, meta


module.exports = {construct_module, get_module, modules_equals}