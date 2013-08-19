{_do, Either, Left, Right, ContT} = require 'fresh-monads'
{read_yaml_file, partial} = require 'cafe4-utils'
async = require 'async'

make_adapter = (adapter, cb) ->
    name = (k for k, v of adapter)[0]
    path = a[name]
    {name, path}


make_default_config = (path, cb) ->


read_config = (path, cb) ->
    read_yaml_file path, (err, data) ->
        if err
            cb (Left err)
        else
            cb (Right data)


read_adapters = (cfg, cb) ->
    unless 'adapters' of cfg
        cb (Left "cafe config is missing adapters file, run 'cafe config init' to make new clear config file")

    async.map make_adapters, cfg.adapters, (err, adapters) ->
        if err
            cb (Left err)
        else
            cb (Right [cfg, adapters])


read_compilers = ([cfg, adapters], cb) ->


get_config = (path, cb) ->


module.exports = {get_config, make_default_config}

