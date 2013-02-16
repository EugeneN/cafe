fs = require 'fs'
path = require 'path'
mkdirp = require 'mkdirp'
{get_mtime} = require('./utils')

exports.get_modules_cache = (cache_path, cache_cb) ->
    get_fn = (module_name) -> path.join cache_path, module_name + '.cache'

    result =
        get: (module_name) -> # Deprecated
            JSON.parse fs.readFileSync (get_fn module_name)

        save_modules_async: (modules, filename, cb) ->
            fs.writeFile(get_fn filename
                         JSON.stringify (modules.map (m) -> m.serrialize_sources())
                         cb)

        get_cached_file_path: (module_name) -> get_fn module_name

        get_cache_mtime_async: (module, cb) -> get_mtime.async (get_fn module.name), cb

    mkdirp cache_path, (err) ->
        if err
            cache_cb "Cannot create cache dirrectory #{err}", null
        else
            cache_cb null, result









