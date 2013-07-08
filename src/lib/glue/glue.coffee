async = require 'async'
path = require 'path'
{exec} = require 'child_process'
{partial, is_file, read_yaml_file, extend, any} = require './../utils'
{error_m, ok, nok}  = require './../monads'
{cont_t, cont_m, maybe_t, maybe_m, logger_t, logger_m,
 domonad, is_null, lift_sync, lift_async } = require 'libmonad'
chokidar = require 'chokidar'


sprite_exclude_keys = ['path']


get_sprite_opts = (sprite) ->
    ret_opts = {}

    for k,v of sprite
        (ret_opts[k] = v) unless k in sprite_exclude_keys
    ret_opts


opts2cmd = (opts) ->
    arg1 = (name, val) -> "--#{name}=#{val}"
    arg2 = (name) -> "-#{name}"
    cmd = ""
    for opt_name, opt_value of opts
        if opt_value is true
            cmd = "#{cmd} #{arg2 opt_name}"
        else
            cmd = "#{cmd} #{arg1 opt_name, opt_value}"
    cmd


_m_is_file = (fn, cb) ->
    is_file.async fn, (err, stat) ->
        if err
            cb nok err
        else unless stat
            cb nok "#{fn} - is not a file"
        else
            cb ok fn


_m_read_file = (fn, cb) ->
    read_yaml_file.async fn, (err, data) ->
        if err then (cb nok err) else (cb ok data)


_m_validate_config = (config, cb) ->
    return (cb nok "sprites section is missing in config") unless config.sprites
    return (cb nok "glue_path section is missing in config") unless config.glue_path
    cb ok config


_m_parse_config = (config, cb) ->
    sprites = config.sprites.map (s) ->
        sprite_name = (k for k, v of s)[0]
        extend s[sprite_name], config.common_opts

    cb ok [config, sprites]


_m_execute_glue = (ctx, [config, sprites], cb) ->
    sprite_iterator = (sprite, sprite_cb) ->
        opts = opts2cmd(get_sprite_opts sprite)
        cmd = "python #{config.glue_path} #{sprite.path} #{opts}"
        ctx.fb.shout "running glue cmd ..."
        ctx.fb.say cmd

        exec cmd, (error, stdout, stderr) ->
            (ctx.fb.say stdout) if stdout
            (ctx.fb.error stderr) if stderr
            unless error
                sprite_cb null, [config, sprite, cmd]
            else
                sprite_cb error

    async.map sprites, sprite_iterator, (err, results) ->
        cb ok [config, sprites, results]


set_watchers = (ctx, execute_results) ->
    paths = (sprite.path for [config, sprite, cmd] in execute_results).map (p)-> path.resolve p
    console.log paths
    watcher = chokidar.watch paths, {ignored: /^\./, persistent: true, ignoreInitial: true}
    watcher.on 'change', (path, stats) -> console.log "changed #{path}"
    ctx.fb.say "Watching changes in sprite folders"


launch_glue = (fn, ctx, cb) ->

    seq = [
        lift_async(2, _m_is_file)
        lift_async(2, _m_read_file)
        lift_async(2, _m_validate_config)
        lift_async(2, _m_parse_config)
        lift_async(3, partial(_m_execute_glue, ctx))
    ]

    (domonad (cont_t error_m()), seq, fn) ([error, [config, sprites, execute_results]])->
        if ctx.own_args.w
            #(return cb error) unless execute_results.length
            set_watchers ctx, execute_results
        else
            cb error

module.exports = {launch_glue}


