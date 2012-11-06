help = [
    """
    Initializes client side application structure.
    Sets initial folders structure.

    Parameters:
        - app_root - base path for application compiling.
        - js_path - path where result js will be stored.
    """
]

path = require 'path'
{make_target} = require '../lib/target'
{make_skelethon} = require '../lib/skelethon/skelethon'
{exists} = require '../lib/utils'

{
    DEFAULT_CS_DIR,
    DEFAULT_CS_BUILD_DIR
} = require '../defs'

cafe_folder_path = './assets/templates/cafe'


check_paths = (ctx, paths) ->
    map_f = (p) -> 
        if (exists p)
            true
        else
            ctx.fb.scream "path #{p} is not exists"
            false

    red_f = (a, b) -> a and b

    paths.map(map_f).reduce(red_f)


get_paths = (ctx) ->
    [ctx.own_args.app_root, ctx.own_args.js_path]


validate_input_params = (ctx) ->
    {app_root, js_path} = ctx.own_args 
    result = true
    unless app_root 
        ctx.fb.scream "app root is not set"
        result = false
    unless js_path
        ctx.fb.scream "js_path is not set"
        result = false
    result


init_app = (ctx, cb) ->
    ctx.fb.say "Creating new client side application"

    cb?('stop') unless (validate_input_params ctx)
    cb?('stop') unless (check_paths ctx, (get_paths ctx))

    # Creating cafe config folder
    make_skelethon 
        skelethon_path: path.resolve cafe_folder_path
        result_path: './'
        fb: ctx.fb

    cb? 'stop'

module.exports = make_target "csinit", init_app, help
