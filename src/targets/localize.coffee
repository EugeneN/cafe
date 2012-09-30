help = [
    """
    <localize> command performs localization of javascript files.

    Parameters:
        --src      - jsFile or dir for translation.
        --locales  - directory with locales for translation.
    """
]

fs = require 'fs'
path = require 'path'

Gettext = require '../lib/gettext'
{make_target} = require '../lib/target'
{localize_run} = require '../lib/localizer'
{say, shout, scream, whisper} = (require '../lib/logger') "Localizer>"


localize = (ctx, cb)->
    locales_root_dir = if ctx.own_args.locales?.length
        path.resolve ctx.own_args.locales
    else
        undefined

    filename = ctx.own_args.src

    if filename? and not fs.existsSync filename
        shout "Bad file #{filename}, it does not exist"
        ctx.print_help()

    return ctx.print_help() unless locales_root_dir and filename

    localize_run locales_root_dir, filename, cb


module.exports = make_target "localize", localize, help
