help = [
    """
    Minifies javascript files.

    Parameters:
        --src            - source dir with js files. This dir is walked
                           recursively.

        --dst            - destination dir for placing minified files into.
                           Minified files will be put to the base dir of each
                           respective source file should this parameter
                           be omitted.

        --pattern=<...>  - file pattern for minification
                           if this argument is specified then the --src parameter
                           is skipped

        -f               - forces minification even if the source file hasn't changed
    """
]

fs = require 'fs'
path = require 'path'
events = require 'events'
Minifier = require '../lib/minifier'
{is_dir, is_file, exists} = require '../lib/utils'
{make_target} = require '../lib/target'
{say, shout, scream, whisper} = (require '../lib/logger') 'Minify>'


minify = (ctx, cb) ->
    unless exists ctx.own_args.src
            ctx.fb.shout "Wrong 'src' parameter for minify: '#{ctx.own_args.src}'"
            ctx.print_help()

    if ctx.own_args.dst? and not (is_dir ctx.own_args.dst)
            ctx.fb.shout "Wrong 'dst' parameter for minify: '#{ctx.own_args.dst}'"
            ctx.print_help()

    minifier = new Minifier ctx

    minifier.minify cb, ctx.own_args.f



module.exports = make_target "minify", minify, help
