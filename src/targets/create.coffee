help = [
    """
    Creates skelethons for installed modules.

    Parameters:
        - app_root - base path for application compiling.
        - js_path - path where result js will be stored.
    """
]

{make_target} = require '../lib/target'

init_app = (ctx, cb) ->
    cb? 'stop'

module.exports = make_target "csinit", init_app, help

