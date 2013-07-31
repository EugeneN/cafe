help = [
    """
    ==================================================================
    This command is used for creating init module structure.
    The logic of skelethon creation is defined by appropriate adaptor.
    ==================================================================
    """
]

{make_target} = require '../lib/target'
{make_skelethon} = require '../lib/skelethon/skelethon'
{SKELETHON_ASSETS_PATH} = require '../defs'
{get_adapters} = require '../lib/adapter'
{extend} = require 'cafe4-utils'
path = require 'path'

list = (ctx, cb) ->
  skels = get_adapters()
          .map((a) -> a.make_skelethon?())
          .filter((a) -> a?)
          .reduce((a, b) -> extend(a, b))

  records = (k for k, v of skels).map((k) -> "  -#{k}").join("  \r\n")

  ctx.fb.say "List of available skelethons: \r\n#{records} \r\n"
  cb 'stop'


skel = (ctx, cb) ->

    args = Object.keys(ctx.full_args)\
           .filter (k) -> k not in ['skel', 'global']

    list(ctx, cb) if 'list' in args

    skels = get_adapters()\
            .map((a) -> a.make_skelethon?())\
            .filter((a) -> a?)\
            .reduce((a, b) -> u.extend(a, b))

    if args[0] of skels
        skel_func = skels[args[0]]
        ctx.fb.say "Skelethon for '#{args[0]}' was found =)"
        skel_values = skel_func args
        skel_values.skelethon_path = path.join(
            path.normalize(SKELETHON_ASSETS_PATH)
            skel_values.skelethon_path
        )
        skel_values.fb = ctx.fb

        make_skelethon skel_values
    else
        ctx.fb.scream "Skelethon for '#{args[0]}' was not found =("

    cb? 'stop'


module.exports = make_target 'skel', skel, help, true
