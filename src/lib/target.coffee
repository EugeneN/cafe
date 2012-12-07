events = require 'events'
path = require 'path'
{is_debug_context, is_debug_context} = require '../lib/utils'
{say, shout, scream, whisper, murmur} = require('../lib/logger') "Target factory>"


{TARGET_PATH} = require '../defs'


run_target = (target_name, args, ctx, success_cb, error_cb) ->
    emitter = ctx.emitter
    try
        target = require path.join TARGET_PATH, target_name
        target.run args, emitter, ctx.fb, success_cb

    catch ex
        if error_cb
            error_cb ex

        else
            scream "Exception raised while executing target `#{target_name}`: '#{ex}'"
            scream "#{ex.stack}"
            
            ctx.fb.scream "Unknown target `#{target_name}`'"
            ctx.fb.scream "Exception raised while executing target `#{target_name}`: '#{ex}'"
            ctx.fb.whisper "#{ex.stack}"

            success_cb? 'target_error', ex

make_target = (name, exec_func, help, single) ->
    #do (name, exec_func, help, single) ->
    # context object to pass to targets
    # put here everything targets may or will ever need

    run = (full_args, emitter, fb, cb) ->
        ctx =
            name: name
            worker: exec_func
            help: help
            debug: -> is_debug_context ctx
            full_args: full_args
            own_args: full_args[name] or {}
            emitter: emitter
            fb: fb
            cafelib: {utils: require './utils'}
            print_help: (cb) ->
                if ctx.help
                    fb.murmur h for h in ctx.help
                else
                    fb.shout 'No help for this target'

                cb?()

        #Object.freeze ctx
        Object.freeze ctx.full_args
        Object.freeze ctx.own_args

        if ctx.own_args.hasOwnProperty 'help'
            ctx.print_help -> cb 'exit_help'

        else
            ctx.worker ctx, cb

    validate_params = ->
        undefined

    Object.freeze {run, validate_params}


module.exports = {make_target, run_target}
