"""
    This is Cafe's main module.
"""
head = [
    """
    Cafe is the build system for client side applications (and more).
    It is written in Coffescript in functional and asyncronous way.

    This is a CLI UI for Cafe v.1

    Parameters:
        -- debug     - include stack traces and other debug info
                       into output

        -- nologo    - exclude logo from output, usefull for sub-commands;

        -- nocolor   - do not use color in output, usefull
                       when directing Cafe's output into a log file;

        -- shutup    - exclude info and warning messages from output.
                       Error and debug messages will be preserved;

        -- version   - returns the current Cafe's version;

        -- help      - this help.

    Sub-commands:
    """
]

fs = require 'fs'
path = require 'path'
async = require 'async'
events = require 'events'
uuid = require 'node-uuid'
growl = require 'growl'

{run_target} = require './lib/target'
{trim, is_debug_context, get_plugins} = require './lib/utils'
{say, shout, scream, whisper,
 murmur, shutup, panic_mode, nocolor} = (require './lib/logger')()
{
    VERSION

    TARGET_PATH

    EVENT_CAFE_DONE

    EXIT_SUCCESS
    EXIT_TARGET_ERROR
    EXIT_OTHER_ERROR
    EXIT_HELP
    EXIT_SIGINT
    EXIT_NO_STATUS_CODE
    EXIT_SIGTERM
    EXIT_PARTIAL_SUCCESS
    EXIT_VERSION_MISMATCH
} = require './defs'


module.exports = ->
    Target_path = TARGET_PATH
    Emitter = new events.EventEmitter
    START_TIME = undefined
    ID = uuid.v4()

    no_action_handler = (fb) ->
        show_help_and_exit fb
        #Emitter.emit EVENT_CAFE_DONE, EXIT_HELP

    show_help_and_exit = (fb) ->
        (head.concat (get_targets()).map (t) -> "    #{t}").map (l) -> fb.murmur l
        Emitter.emit EVENT_CAFE_DONE, EXIT_HELP

    show_version_and_exit = (fb) ->
        fb.say "Current version: #{get_version()}"
        Emitter.emit EVENT_CAFE_DONE, EXIT_HELP

    target_run_factory = (target_name, full_args, proto_ctx) ->
        (cb) ->
            run_target target_name, full_args, proto_ctx, cb

    ready = ({target_path, emitter, exit_cb, fb}) ->
        Target_path = target_path if target_path
        Emitter = emitter if emitter

        proto_ctx =
            emitter: Emitter
            fb: fb

        # the one and only exit point
        Emitter.on EVENT_CAFE_DONE, (status) ->
            say "Coffee #{ID} brewed in <#{(new Date - START_TIME) / 1000} seconds> at #{new Date}"
            fb.say "Coffee #{ID} brewed in <#{(new Date - START_TIME) / 1000} seconds> at #{new Date}"
            exit_cb (if status is undefined then EXIT_NO_STATUS_CODE else status)


        # global entry point
        go = ({args}) ->
            cb = ->
                if args.global?.hasOwnProperty 'help'
                    show_help_and_exit fb

                else if args.global?.hasOwnProperty 'version'
                    show_version_and_exit fb

                else
                    seq = ((target_run_factory target, args, proto_ctx) \
                            for target of args when target isnt "global")

                    if (seq.length is 0) then (no_action_handler fb) else (run_seq args, seq, fb)

            # making updating explicit until issue with sudo password will be solved
            if process.getuid() is 0
                run_target 'update', args, proto_ctx, cb
            else
                cb()

        {go}

    run_seq = (argv, seq, fb) ->
        is_growl = not argv.global.hasOwnProperty 'nogrowl'
        START_TIME = new Date

        done = (error=null, results) =>
            switch error
                when null
                    EXIT_STATUS = EXIT_SUCCESS

                when 'stop'
                    whisper 'Stop from task'
                    fb.whisper 'Stop from task'
                    EXIT_STATUS = EXIT_SUCCESS

                when 'sigint'
                    whisper 'Sigint from outer world'
                    fb.whisper 'Sigint from outer world'
                    EXIT_STATUS = EXIT_SIGINT

                when 'target_error'
                    whisper 'Error from task'
                    fb.whisper 'Error from task'
                    growl('Cafe error from task') if is_growl
                    EXIT_STATUS = EXIT_TARGET_ERROR

                when 'sub_cafe_error'
                    whisper "Error from sub-cafe: #{results}"
                    fb.whisper "Error from sub-cafe: #{results}"
                    growl('Cafe error') if is_growl
                    EXIT_STATUS = results

                when 'partial_success'
                    whisper "Finished with errors: #{results}"
                    fb.whisper "Finished with errors: #{results}"
                    EXIT_STATUS = EXIT_PARTIAL_SUCCESS

                when 'version_mismatch'
                    whisper "No further processing will be taken"
                    fb.whisper "No further processing will be taken"
                    growl('Cafe version mismatch') if is_growl
                    EXIT_STATUS = EXIT_VERSION_MISMATCH

                when 'exit_help'
                    EXIT_STATUS = EXIT_HELP

                when 'bad_recipe'
                    scream "#{results}"
                    fb.scream "#{results}"
                    EXIT_STATUS = EXIT_OTHER_ERROR

                when 'bad_ctx'
                    scream "#{results}"
                    fb.scream "#{results}"
                    growl('Bad context') if is_growl
                    EXIT_STATUS = EXIT_OTHER_ERROR

                else
                    scream "Error encountered: #{error}"
                    whisper "#{error.stack}"
                    fb.scream "Error encountered: #{error}"
                    fb.whisper "#{error.stack}"
                    growl("Cafe encountered error #{error}") if is_growl

                    EXIT_STATUS = EXIT_OTHER_ERROR

            Emitter.emit EVENT_CAFE_DONE, EXIT_STATUS

        async.series seq, done

    get_version = -> VERSION

    get_targets = ->
        (get_plugins TARGET_PATH).map (target_name) -> target_name


    {ready, get_version, get_targets}

