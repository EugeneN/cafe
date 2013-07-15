async = require 'async'
path = require 'path'
{exec} = require 'child_process'
{partial, is_file, read_yaml_file, extend, any} = require './../utils'
{error_m, ok, nok}  = require '../monads'
{cont_t, cont_m, maybe_t, maybe_m, logger_t, logger_m,
 domonad, is_null, lift_sync, lift_async } = require 'libmonad'
{watcher} = require '../cafe-watch'


m_is_file = (fn, cb) ->
    is_file.async fn, (err, stat) ->
        if err
            cb nok err
        else unless stat
            cb nok "#{fn} - is not a file"
        else
            cb ok fn


m_read_file = (fn, cb) ->
    read_yaml_file.async fn, (err, data) ->
        if err then (cb nok err) else (cb ok data)


m_validate_config = (config, cb) ->
    return (cb nok "sprites section is missing in config") unless config.sprites
    return (cb nok "glue_path section is missing in config") unless config.glue_path
    cb ok config


m_parse_config = (config, cb) ->
    sprites = config.sprites.map (s) ->
        sprite_name = (k for k, v of s)[0]
        sprite = s[sprite_name]
        sprite.opts = sprite.opts.concat config.common_opts
        sprite.path = path.resolve sprite.path
        sprite

    cb ok [config, sprites]


m_execute_glue = (ctx, [config, sprites], cb) ->
    sprite_iterator = (sprite, sprite_cb) ->
        opts = sprite.opts.join " "
        cmd = "python #{config.glue_path} #{sprite.path} #{opts}"
        ctx.fb.shout "running glue cmd ..."
        ctx.fb.say cmd

        exec cmd, (error, stdout, stderr) ->
            (ctx.fb.say stdout) if stdout
            unless error
                sprite_cb null, [config, sprite, cmd]
            else
                sprite_cb error

    async.map sprites, sprite_iterator, (err, results) ->
        unless err
            cb ok [config, sprites, results]
        else
            cb nok err


set_watchers = (ctx, execute_results) ->
    w_handler = (path, stats) ->
        ctx.fb.say "Path #{path} changed"

        result = (execute_results.filter(
            ([config, sprite, cmd]) -> sprite.path in path))

        if result.length
            [config, sprite, cmd] = result[0]

            exec cmd, (error, stdout, stderr) ->
                (ctx.fb.say stdout) if stdout
                (ctx.fb.scream stderr) if stderr

    error_handler = (error) -> ctx.fb.shout "Watcher error #{error}"

    paths = (sprite.path for [config, sprite, cmd] in execute_results)

    watcher({  paths
             , change_handler: w_handler
             , add_handler: w_handler
             , remove_handler: w_handler
             , error_handler})

    ctx.fb.say "Watching changes in sprite folders"


launch_glue = (fn, ctx, cb) ->

    seq = [
        lift_async(2, m_is_file)
        lift_async(2, m_read_file)
        lift_async(2, m_validate_config)
        lift_async(2, m_parse_config)
        lift_async(3, partial(m_execute_glue, ctx))
    ]

    (domonad (cont_t error_m()), seq, fn) ([error, resp])->
        unless error
            [config, sprites, execute_results] = resp
            if ctx.own_args.w
                (return cb error) if error
                set_watchers ctx, execute_results
            else
                cb error
        else
            cb error

module.exports = {launch_glue}