help = [
    """
    Updates Cafe from the repo if newer version is available. 
    Re-runs updated cafe with the arguments passed alongside with 'update'.

    Parameters:

        --help
            this help
    """
]

fs = require 'fs'
path = require 'path'
request = require 'request'
{spawn, exec} = require 'child_process'

{make_target} = require '../lib/target'
{trim, filter_dict} = require '../lib/utils'
{say, shout, scream, whisper} = (require '../lib/logger') 'Update>'


{SUB_CAFE, VERSION, EVENT_CAFE_DONE, EXIT_SUCCESS,
 CLEANUP_CMD, UPDATE_CMD, CB_SUCCESS} = require '../defs'


build_update_reenter_cmd = (ctx) ->
    arg1 = (arg) -> "-#{arg}"
    arg2 = (arg, val) -> "--#{arg}#{if val is undefined then '' else '=' + val}"
    format_arg = (arg, val) -> if val is true then arg1(arg) else arg2(arg, val)

    # we don't want logo to be printed the second time
    cmd_args = ['--nologo', '--noupdate']

    # adding global arguments before all commands
    cmd_args.push(format_arg(arg, val)) for arg, val of ctx.global when arg isnt 'update'

    # adding commands and their arguments
    for command, args of filter_dict(ctx, (k, v) -> k not in ['global', 'update'])
        cmd_args.push "#{command}"
        cmd_args.push(format_arg(arg, val)) for arg, val of args

    cmd_args

reenter = (ctx, cb) ->
    cmd_args = build_update_reenter_cmd ctx.full_args
    ctx.fb.say "Re-entering with '#{cmd_args.join ' '}'"

    run = spawn SUB_CAFE, cmd_args
    rlog = (require '../lib/logger') 'Reenter>'

    run.stdout.on 'data', (data) -> ctx.fb.say "#{data}".replace /\n$/, ''
    run.stderr.on 'data', (data) -> ctx.fb.scream "#{data}".replace /\n$/, ''
    run.on 'exit', (code) ->
        ctx.fb.shout "Re-enter finished with code #{code}"
        cb? 'stop'

maybe_update = (ctx, cb) ->
    if ctx.full_args.global?.hasOwnProperty 'noupdate'
        return cb()

    run = (ctx, cmd, run_cb) ->
        [cmd, args...] = cmd.split ' '

        child = spawn cmd, args

        child.stdout.on 'data', (data) -> ctx.fb.say "#{data}".replace /\n$/, ''
        child.stderr.on 'data', (data) -> ctx.fb.shout "#{data}".replace /\n$/, ''
        child.on 'exit', (rc) ->
            run_cb CB_SUCCESS, rc

    reenter_cb = ->
        ctx.emitter.emit EVENT_CAFE_DONE, EXIT_SUCCESS

    run ctx, CLEANUP_CMD, (err, rc) ->
        run ctx, UPDATE_CMD, (err, rc) ->
            if rc is 0
                ctx.fb.say "Cafe update succeeded"
                reenter ctx, reenter_cb
            else
                ctx.fb.shout "Cafe update failed: #{code}"
                cb()


module.exports = make_target "update", maybe_update, help
