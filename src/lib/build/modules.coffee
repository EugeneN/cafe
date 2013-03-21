{or_, partial, extend} = require '../utils'
_path = require 'path'
{NPM_MODULES_PATH} = require '../../defs'
u = require 'underscore'
{skip_or_error_m, OK} = require '../monads'
{domonad} = require 'libmonad'

get_module = ({path, name, deps, type, location, prefix_meta}) ->

    location or= "fs"
    type or= "commonjs"
    deps or= []
    prefix_meta or={}

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

    serrialize_meta = -> {name, path, type, location, deps, prefix_meta}

    {
    prefix_meta
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
        [path, arg2, arg3] = meta[name]

        if Array.isArray arg2
            [deps, type] = [arg2, arg3]
        else
            [deps, type] = [arg3, arg2]

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


_m_check_name_prefix = (module) ->
    prefix_regexp = /([a-z+]+?):\/\/(.+)/
    npm_path_regexp = /([A-Za-z0-9-_]+)@?(.+)?/

    if prefix_regexp.test module.path
        [_, prefix, npm_path] = module.path.match prefix_regexp

        if prefix is "npm"        

            unless npm_path_regexp.test npm_path
                return ["npm module #{module.name} has wrong format", false, module]

            [_, npm_module_name, version] = npm_path.match npm_path_regexp
            
            module.prefix_meta = extend(
                module.prefix_meta 
                {prefix, npm_path, version, npm_module_name})
            
            module = extend module, {path: _path.join(NPM_MODULES_PATH, module.prefix_meta.npm_module_name)}

        module
    else
        module


construct_module = (meta, ctx) ->
    seq = [
        _m_check_format
        _m_parse_from_string
        _m_parse_from_list
        _m_parse_from_dict
    ]

    [err, skip, module] = (domonad skip_or_error_m(), seq, meta)
    unless err
        module = _m_check_name_prefix module
    [err, skip, module]

module.exports = {construct_module, get_module, modules_equals}