fs = require 'fs'
path = require 'path'
mkdirp = require '../../third-party-lib/mkdirp'
{get_mtime, extend} = require('./utils')

exports.get_modules_cache = (cache_path, cache_cb) ->
    get_fn = (module_name) -> path.join cache_path, module_name + '.cache'

    result =
        get: (module_name) -> # Deprecated
            JSON.parse fs.readFileSync (get_fn module_name)

        save_modules_async: (modules, cached_sources, filename, cb) ->
            reducer = (a, b) ->
                new_key = {}
                new_key[b.name] = b
                extend a, new_key

            if cached_sources
                for m in modules
                    cached_sources[m.name] = m.serrialize_sources()
                to_save = cached_sources
            else
                to_save = ((modules.map (m) -> m.serrialize_sources()).reduce reducer, {})

            fs.writeFile (get_fn filename), JSON.stringify(to_save), cb

        get_modules_async: (filename, cb) ->
            fs.readFile (get_fn filename), (err, data) ->
                data = if err
                    null
                else
                    try
                        JSON.parse data
                    catch er
                        parse_error = "Error while reading cache file #{get_fn filename} #{er}"

                cb parse_error, data

        get_cached_file_path: (module_name) -> get_fn module_name

        get_cache_mtime_async: (module, cb) -> get_mtime.async (get_fn module.name), cb

    mkdirp cache_path, (err) ->
        if err
            cache_cb "Cannot create cache dirrectory #{err}", null
        else
            cache_cb null, result









