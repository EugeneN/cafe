CLEAN_ALL_PASS = 'allyesiamsure'

help = [
    """
    Prepares your coffee according to the menu selection.
    Prints current menu if called without paramaters.

    Parameters:

        --new=<name> <any other cafe options>
            saves all cafe options to the menu under the name <name>

        --expire <name>
            removes specified dish from the menu
            expires the whole menu if <name> == #{CLEAN_ALL_PASS}

        --show <name>
            shows ingredients

        --justatea <name>
            just prints commands in plain text

        <name>
            serves ordered menu for your pleasure.
            Bon appetite!

        --help
            this help

        prints current menu if called without arguments.
    """
]

{make_target} = require '../lib/target'
menu = require '../lib/menu'


# entry point
waiter = (ctx, cb) ->
    # XXX check out possible file operations race conditions below!
    
    [arg1, arg2] = Object.keys(ctx.full_args).filter (i) -> i not in ['global', 'menu']

    if ctx.own_args.new
        menu._do_new_menu ctx.own_args.new, ctx, cb

    else if (ctx.own_args.hasOwnProperty 'expire') and arg1
        menu._do_expire_menu arg1, ctx, cb

    else if (ctx.own_args.hasOwnProperty 'show') and arg1
        menu._do_show_menu arg1, ctx, cb

    else if (ctx.own_args.hasOwnProperty 'justatea') and arg1
        menu._do_just_tea arg1, ctx, cb

    else if ctx.own_args.hasOwnProperty 'help'
        menu._do_help ctx, cb

    else if arg1
        menu._do_serve_menu arg1, ctx, cb

    else
        menu._do_default ctx, cb

module.exports = make_target "menu", waiter, help
