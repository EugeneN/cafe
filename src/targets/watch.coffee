help = [
    """
    Launches watcher that will continuously watch given directory
    for any file modifications underneath and will run the `watch cycle`
    on all such events.

    Parameters:
        - src  - argument will be automatically substituted for each `watch cycle`
                 with the path of the changed module if appropriate:

        - skip - skip dir in src

    * Example:

    > cafe compile --src=uaprom/uaprom/cs minify --src=uaprom/uaprom/js watch
          |                                                          |
          |__________________ watch cycle ___________________________|


    Parameters:
        --src       - path to the direcory with cs modules for monitoring
    """
]

fs = require 'fs'
path = require 'path'
watcher = require '../lib/watcher'
{make_target} = require '../lib/target'
{filter_dict, is_dir, is_debug_context} = require '../lib/utils'
{say, shout, scream, whisper} = (require '../lib/logger') "Watcher>"


{COFFEE_PATTERN} = require '../defs'


good_watch_seq = (ctx) ->
    seq = Object.keys(ctx.full_args).filter (k) -> k not in ['watch', 'global']

    if seq.length is 0
        false
    else
        true

watch = (ctx, cb) ->
    watch_src = ctx.own_args.src or ctx.full_args.src

    unless is_dir watch_src
        ctx.fb.scream "Missing '--src' parameter for the watch: '#{watch_src}'"
        ctx.fb.scream "Eat help instead:\n"
        ctx.print_help()

    unless good_watch_seq ctx
        ctx.fb.scream "Looks like the command sequence for the watch cycle is bad"
        ctx.fb.scream "Eat help instead:\n"
        ctx.print_help()

    watcher_ctx =
        fb: ctx.fb
        orig_ctx: ctx
        cb: cb
        watch_root: watch_src

    watcher.watch Object.freeze watcher_ctx

    ctx.fb.say "Watching how coffee is growing"
    ctx.fb.say "Press `Ctrl-c` to stop watching."

    # cb?() - no callback here or main process will exit


module.exports = make_target "watch", watch, help
