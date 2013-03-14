path = require 'path'
async = require 'async'
fs = require 'fs'
{is_dir, partial} = require './utils'
{ADAPTERS_PATH, ADAPTER_FN, JS_EXT} = require '../defs'
fn_pattern = "#{ADAPTER_FN}#{JS_EXT}"
{cont_t, domonad, lift_sync, lift_async, logger_t} = require 'libmonad'
{error_m, OK} = require './monads'

read_adapters_dir = (adapters_path, cb) ->
    fs.readdir adapters_path, (err, files) ->
        cb [err, files]

define_folders = (adapters_path, files, adapter_folders_cb) -> # TOTEST
    is_dir_iterator = (file, cb) ->
        is_dir.async file, (err, result) ->
            if err
                cb false
            else
                cb result

    files = (files.map (f) -> path.join adapters_path, f)

    async.filter files, is_dir_iterator, (dirs) ->
        adapter_folders_cb [OK, dirs]

define_adapters = (fn_pattern, dirs, cb) -> # TOTEST
    has_adapter_file_iterator = (dir, cb) ->
        fs.exists (path.join dir, fn_pattern), cb

    async.filter dirs, has_adapter_file_iterator, (adapters_paths) ->
        cb [OK, adapters_paths]


require_adapters = (fn_pattern, adapters_paths) ->
    # TODO: make parallel
    [OK, adapters_paths.map (a) -> require (path.join a, fn_pattern)]

get_adapters = ->
    (fs.readdirSync ADAPTERS_PATH)
        .map((p) -> path.join(ADAPTERS_PATH, p))
        .filter((fn) -> (is_dir fn) and fn_pattern in fs.readdirSync fn)
        .map (d) -> require(path.join d, fn_pattern)


get_adapters.async = (adapters_dir, fn_pattern, adapters_cb) ->
    adapters_dir or= ADAPTERS_PATH
    fn_pattern or= "#{ADAPTER_FN}#{JS_EXT}"
    sequence = [
        lift_async(2, read_adapters_dir)
        lift_async(3, partial(define_folders, adapters_dir))
        lift_async(3, partial(define_adapters, fn_pattern))
        lift_sync(1, partial(require_adapters, fn_pattern))
    ]

    worker_monad = cont_t error_m()
    (domonad worker_monad, sequence, adapters_dir) ([err, results]) ->
        adapters_cb err, results

module.exports = {get_adapters}


