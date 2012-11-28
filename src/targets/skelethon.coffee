help = [
    """
    This command is used for creating init module structure.
    The logic of skelethon creation is defined by appropriate adaptor.
    """
]

{make_target} = require '../lib/target'
{make_skelethon} = require '../lib/skelethon/skelethon'

skelethon = (ctx, cb) ->
    cb? 'stop'

module.exports = make_target 'skelethon', skelethon, help, true
