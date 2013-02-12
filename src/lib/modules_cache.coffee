fs = require 'fs'
path = require 'path'
mkdirp = require 'mkdirp'
{get_mtime} = require('./utils')

exports.get_modules_cache = (cache_path) ->

    get_fn = (module_name) ->
        path.join cache_path, module_name + '.cache'

    get: (module_name) ->
        JSON.parse fs.readFileSync (get_fn module_name)

    save: (cache) ->
        module_name = get_fn cache.module.name

        write_file = (cached_mod) ->
            fs.writeFileSync (get_fn cached_mod.module.name), (JSON.stringify cached_mod)

        if path.existsSync (path.dirname module_name)
            write_file cache
        else
            mkdirp (path.dirname module_name), (err) ->
                throw "Can not create cache dirrectory #{err}" if err
                write_file cache

    get_cached_file_path: (module_name) ->
        get_fn module_name

    get_cache_mtime: (module) ->
        try
            get_mtime (get_fn module.name).toString()
        catch e
            0

    get_cache_mtime_async: (module, cb) -> get_mtime.async (get_fn module), cb







