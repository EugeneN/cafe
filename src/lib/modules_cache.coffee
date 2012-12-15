fs = require 'fs'
path = require 'path'
mkdirp = require 'mkdirp'
{get_mtime} = require('./utils')

exports.get_modules_cache = (cache_path) ->

    get_fn = (module_name) ->
        path.join cache_path, module_name + '.cache'

    get: (module_name) ->
        JSON.parse fs.readFileSync (get_fn module_name)

    save: (module) ->
        module_name = get_fn module.name

        write_file = (mod) ->
            fs.writeFileSync (get_fn mod.name), (JSON.stringify mod)

        if path.existsSync (path.dirname module_name)
            write_file module
        else
            mkdirp (path.dirname cmodule_name), (err) ->
                throw "Can not create cache dirrectory #{err}" if err
                write_file module

    get_cached_file_path: (module_name) ->
        get_fn module_name

    get_cache_mtime: (module) ->
        try
            get_mtime (get_fn module.name).toString()
        catch e
            0

