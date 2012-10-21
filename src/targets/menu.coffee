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

fs = require 'fs'
path = require 'path'
async = require 'async'
{compose} = require 'underscore'
{fork, spawn} = require 'child_process'

{make_target} = require '../lib/target'
{say, shout, scream, whisper} = require('../lib/logger') "Menu>"
{filter_dict, is_debug_context, read_json_file, add} = require '../lib/utils'


{MENU_FILENAME, SUB_CAFE} = require '../defs'

read_menu = (fn) -> (read_json_file fn) or {}

write_menu = (fn, data) ->
    try
        # XXX http://nodemanual.org/0.6.9/js_doc/JSON.html#JSON.stringify
        # for json pretty printing
        fs.writeFileSync fn, JSON.stringify(data, null, 4)
    catch e
        scream "Error writing menu: '#{e}'"

build_cmd = (current_ctx, my_menu) ->
    arg1 = (arg) -> "-#{arg}"
    arg2 = (arg, val) -> "--#{arg}#{if val is undefined then '' else '=' + val}"
    format_arg = (arg, val) -> if val is true then arg1(arg) else arg2(arg, val)

    # we don't want logo to be printed the second time
    cmd_args = ['--nologo', '--child']

    # injecting debug argument from the current context if any
    cmd_args.push '--debug' if is_debug_context current_ctx

    # adding global arguments before all commands
    cmd_args.push(format_arg(arg, val)) for arg, val of my_menu.global

    # adding commands and their arguments
    for command, args of filter_dict(my_menu, (k, v) -> k isnt 'global')
        cmd_args.push "#{command}"
        cmd_args.push(format_arg(arg, val)) for arg, val of args

    cmd_args


cook_tea = (current_ctx, my_menu, cb) ->
    cmd_args = build_cmd current_ctx, my_menu

    current_ctx.fb.say "#{path.basename process.argv[1]} #{cmd_args.join(" ")}\n"
    current_ctx.fb.shout "Do you have some tips for me?"

    cb? 'stop'

cook_menu = (current_ctx, my_menu, cb) ->
    cmd_args = build_cmd current_ctx, my_menu

    current_ctx.fb.say "Replaying command sequence `#{cmd_args.join(" ")}`"

    child = spawn SUB_CAFE, cmd_args #, {silent: true}

    child.on 'message', (m) -> current_ctx.fb.murmur m

    # when forking child std* is assosiated with parent's ones
    child.stdout.on 'data', (data) -> current_ctx.fb.say "#{data}".replace /\n$/, ''
    child.stderr.on 'data', (data) -> current_ctx.fb.scream "#{data}".replace /\n$/, ''
    child.on 'exit', (code) ->
        if code is 0
            current_ctx.fb.say "Command sequence succeeded"
            # should stop to prevent cafe processing menu's subcomamnds as own commands
            cb? 'stop'
        else
            current_ctx.fb.scream "Command sequence failed with code #{code}"
            cb? "sub_cafe_error", code

    # cb?('stop') no exit or the process will exit

store_new_menu = (reader, writer, new_menu_item_name, new_menu_item_value) ->
    # existing_menu is frozen
    existing_menu = reader()

    new_item = {}
    new_item[new_menu_item_name] = new_menu_item_value

    new_menu = add existing_menu, new_item
    writer new_menu

clean_menu = (reader, writer, item_to_clean) ->
    if item_to_clean is CLEAN_ALL_PASS
        writer {}

    else
        existing_menu = reader()
        writer filter_dict existing_menu, (k, v) -> k isnt item_to_clean

# entry point
waiter = (ctx, cb) ->
    # XXX check out possible file operations race conditions below!

    read_my_menu = read_menu.partial MENU_FILENAME
    write_my_menu = write_menu.partial MENU_FILENAME

    _do_new_menu = (name) ->
        new_menu = filter_dict ctx.full_args, (k, v) -> k isnt 'menu'

        ctx.fb.say "Saving new menu #{name}..."
        store_new_menu read_my_menu, write_my_menu, name, new_menu
        ctx.fb.say "done."

        cb? 'stop'

    _do_expire_menu = (name) ->
        ctx.fb.say "Cleaning menu item #{item_to_clean}"
        clean_menu read_my_menu, write_my_menu, name
        ctx.fb.say "done."

        cb? 'stop'

    _do_show_menu = (name) ->
        my_menu = read_my_menu()

        if my_menu[name]
            ctx.fb.say "Ingredients of the menu '#{name}':"
            ctx.fb.say "\n", my_menu[name]

            cb? 'stop'

        else
            ctx.fb.shout "Sorry, we don't have a dish `#{name}` right now :-("
            cb? 'stop'

    _do_serve_menu = (name) ->
        my_menu = read_my_menu()

        if my_menu[name]
            cook_menu ctx, my_menu[name], cb

        else
            ctx.fb.shout "Sorry, we don't have a dish `#{name}` right now :-("
            cb? 'stop'

    _do_just_tea = (name) ->
        my_menu = read_my_menu()

        if my_menu[name]
            cook_tea ctx, my_menu[name], cb

        else
            ctx.fb.shout "Sorry, we don't have a tea sort `#{name}` right now :-("
            cb? 'stop'

    _do_help = ->
        ctx.fb.murmur 'help'
        ctx.print_help()

    _do_default = ->
        menu = read_my_menu()

        if Object.keys(menu).length > 0
            ctx.fb.say "Menu:"
            ctx.fb.say "- #{k}" for k of read_my_menu()

        else
            ctx.fb.shout "We have nothing to offer right now :-("

        cb? 'stop'

    [arg1, arg2] = Object.keys(ctx.full_args).filter (i) -> i not in ['global', 'menu']

    if ctx.own_args.new
        _do_new_menu ctx.own_args.new

    else if (ctx.own_args.hasOwnProperty 'expire') and arg1
        _do_expire_menu arg1

    else if (ctx.own_args.hasOwnProperty 'show') and arg1
        _do_show_menu arg1

    else if (ctx.own_args.hasOwnProperty 'justatea') and arg1
        _do_just_tea arg1

    else if ctx.own_args.hasOwnProperty 'help'
        _do_help()

    else if arg1
        _do_serve_menu arg1

    else
        _do_default()


module.exports = make_target "menu", waiter, help
