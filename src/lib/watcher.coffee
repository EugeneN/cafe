fs = require 'fs'
path = require 'path'
async = require 'async'
watch = require 'watch'
{fork, spawn} = require 'child_process'

{say, shout, scream, whisper} = (require './logger') "Watcher>"
{maybe_build, filter_dict, is_array, is_debug_context} = require './utils'


SEP = '/'
{WATCH_FN_PATTERN, SUB_CAFE} = require '../defs'


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
        modules = [ctx.watch_root]
        builder = build.partial ctx, build_cmd.partial ctx.orig_ctx.full_args

        # for module_root in modules
        modules.map (module_root) ->
            builder module_root

            skip = if ctx.orig_ctx.own_args.skip
                if is_array ctx.orig_ctx.own_args.skip
                    ctx.orig_ctx.own_args.skip.map (path_suffix) ->
                        path.resolve module_root, path_suffix
                else
                    [path.resolve module_root, ctx.orig_ctx.own_args.skip]
            else
                undefined

            watch.watchTree(
                module_root

                { ignoreDotFiles: true }

                (file, curr, prev) =>
                    unless (skip and (path_matches skip, file))
                        fn = path.basename file
                        if WATCH_FN_PATTERN.test fn
                            if curr and (curr.nlink is 0 or +curr.mtime isnt +prev?.mtime)
                                ctx.fb.say "Coffee #{file} is cold. Preparing new..."

                                builder (_get_build_dir ctx.watch_root, file)

                                # TODO: implement tests build.
                                #@build_tests(@_get_build_dir(file))
            )

        ctx.fb.say "Started growing Coffee on the plantation '#{ctx.watch_root}'"

