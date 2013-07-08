help = [
    """
    ==================================================================
    This command is used for launching glue
    ==================================================================
    """
]


{make_target} = require '../lib/target'
{launch_glue} = require '../lib/glue/glue'


glue = (ctx, cb) ->
    {config} = ctx.own_args
    return (cb? 'Glue --config param is missing') unless config
    launch_glue config, ctx, cb


module.exports = make_target 'glue', glue, help, true