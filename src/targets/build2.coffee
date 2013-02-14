help = [
    """

    """
]


{make_target} = require '../lib/target'
{run_build_sequence} = require '../lib/build/build_sequence'
{is_dir} = require '../lib/utils'
{CB_SUCCESS} = require '../defs'

check_ctx = (ctx, cb) ->
    unless ctx.own_args.app_root and ctx.own_args.build_root
        cb ["app_root and/or build_root arguments missing", 'bad_ctx']

    else unless is_dir ctx.own_args.app_root
        cb ["App root #{ctx.own_args.app_root} is not a directory", 'bad_ctx']

    else
        cb CB_SUCCESS, true


build2 = (ctx, cb) ->
    check_ctx ctx, (err, valid) ->
        if err
            cb err
        else
            run_build_sequence ctx, cb


module.exports = make_target "build2", build2, help
