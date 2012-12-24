path = require 'path'
chokidar = require 'chokidar'
{fork, spawn} = require 'child_process'

{say, shout, scream, whisper} = (require './logger') "Watcher>"
{maybe_build, filter_dict, is_array, is_debug_context} = require './utils'


SEP = '/'
{WATCH_FN_PATTERN, SUB_CAFE, THRESHOLD_INTERVAL} = require '../defs'

THRESHOLD_QUEUE_ACTIVE = false
THRESHOLD_QUEUE_EMPTY = true

build_cmd = (full_args, build_path) ->
    ###
    Function for initializing cmd for executing after some file was changed.
    ###

    # filtering out self and global args
    filtered_args = filter_dict full_args, (k, v) -> k not in ['watch', 'global']

    arg1 = (arg) -> "-#{arg}"
    arg2 = (arg, val) -> "--#{arg}#{if val is undefined then '' else '=' + val}"

    format_arg = (arg, val) ->
        if val is true
            arg1(arg)
        else
            arg2(arg, val)

    filter_arg = (command, arg, val) ->
        if val is true
            arg1(arg)
        else
            arg2(arg, val)

    # we don't want logo to be printed the second time
    cmdline = ['--nologo', '--child']

    # injecting debug argument from the current context if any
    cmdline.push '--debug' if is_debug_context full_args

    # adding global arguments before all commands
    cmdline.push(format_arg(arg, val)) for arg, val of full_args.global

    # adding commands and their arguments, modifying if applicable
    for command, args of filtered_args
        cmdline.push "#{command}"
        cmdline.push(filter_arg(command, arg, val)) for arg, val of args

    cmdline

build = (ctx, build_cmd_gen, build_root) ->
    cmd_args = build_cmd_gen build_root
    opts =
        env: process.env
        cwd: process.env.PWD

    child = spawn SUB_CAFE, cmd_args, opts

    child.on 'message', (m) -> ctx.fb.murmur m

    # when forking child std* is assosiated with parent's ones
    child.stdout.on 'data', (data) -> ctx.fb.say "#{data}".replace /\n$/, ''
    child.stderr.on 'data', (data) -> ctx.fb.scream "#{data}".replace /\n$/, ''
    child.on 'exit', (code) ->
        if code is 0
            ctx.fb.say "=== Watch cycle sequence succeeded ==========================="
        else
            ctx.fb.scream "=== Watch cycle sequence failed with code #{code} ==========="


_get_build_dir = (watch_root, file) ->
    base = (i for i in watch_root.split(SEP) when i)
    current = (i for i in file.split(SEP) when i)

    base.concat(current[base.length...][0]).join(SEP)

path_matches = (paths, s) ->
    full_s = path.resolve s
    (paths.map (p) ->
        r = new RegExp "^#{path.resolve p}"
        r.test full_s).reduce (a, b) ->
            a or b

module.exports =
    watch: (ctx) ->
        modules = [path.resolve ctx.watch_root]
        builder = build.partial ctx, build_cmd.partial ctx.orig_ctx.full_args

        # for module_root in modules
        modules.map (module_root) ->

            check_queue = ->
                unless THRESHOLD_QUEUE_EMPTY
                    do_build()
                else
                    THRESHOLD_QUEUE_ACTIVE = false

            do_build = ->
                setTimeout check_queue, THRESHOLD_INTERVAL

                THRESHOLD_QUEUE_ACTIVE = true
                THRESHOLD_QUEUE_EMPTY = true

                builder module_root

            #do_build()

            skip = if ctx.orig_ctx.own_args.skip
                if is_array ctx.orig_ctx.own_args.skip
                    ctx.orig_ctx.own_args.skip.map (path_suffix) ->
                        path.resolve module_root, path_suffix
                else
                    [path.resolve module_root, ctx.orig_ctx.own_args.skip]
            else
                undefined

            change_handler =
                (file) =>
                    unless (skip and (path_matches skip, file))
                        fn = path.basename file
                        if WATCH_FN_PATTERN.test fn
                            if THRESHOLD_QUEUE_ACTIVE
                                shout "#{file} has been changed, but skipping brewing due to threshold limit"
                                THRESHOLD_QUEUE_EMPTY = false

                            else
                                say "Coffee #{file} is cold. Preparing new..."
                                do_build()

            watcher = chokidar.watch module_root, {ignored: /^\./, persistent: true, ignoreInitial: true}
            watcher.on 'add', change_handler
            watcher.on 'change', change_handler
            watcher.on 'error', (error) -> ctx.fb.scream "watcher encauntered an error #{error}"

        ctx.fb.say "Watching application changes ...'#{ctx.watch_root}'\n Press `Ctrl-c` to stop watching."
