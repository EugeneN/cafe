# ************************************ easy-opts **************************************
#
#   Lib for parsing command arguments
#
#   Example:
#
#   cmd  --global_arg=g_arg  some_command -f   some_command2 --global_arg=g_arg_custom --cmd2arg=arg2
#
#        \_____global_args_|  \__command1____|  \_____________________command2______________________|
#
#
#   easy-opts will return such structure
#
#       { 
#           global: 
#               {
#                   global_arg: 'g_arg'   // --- defined global argument to all commands
#               }
#
#           some_command :
#               { 
#                   global_arg: 'g_arg',
#                   f : true
#               }
#
#           some_command2 : 
#               {
#                   global_arg: 'g_arg_custom',   // --- overwrites global arg
#                   cmd2arg: 'arg2'
#
#               }
#       }
#
# Command-attributes :
# Boolean:
#  -f              -is parsed as f:true
#  --attr=some     -is parsed as attr:some

GLOBAL = 'global'

toArray = (value = []) -> if Array.isArray(value) then value else [value]

filter_dict = (d, filter_fn) ->
    ret = {}
    for own k, v of d
        ret[k] = v if filter_fn k, v
    Object.freeze ret


f = (arg) ->
    if arg[0..1] is '--'
        return arg.split '='

    if arg[0] is '-'
        return [arg, true]

    arg


fsm = ->
    s = GLOBAL

    (i) ->
        if i[0] isnt '-'
            s = i
            [s, null]
        else
            [s, i]


r = (prev, cur) ->
    prev[cur[0]] or= {}

    if cur[1]?
        option = f(cur[1])

        command_key = cur[0]
        option_key = option[0].replace('--','').replace('-', '')

        unless prev[command_key].hasOwnProperty option_key
            prev[command_key][option_key] = option[1]
        else
            prev[command_key][option_key] = toArray(prev[command_key][option_key])
            prev[command_key][option_key].push option[1]

    prev


parse_args = (argv) -> 
    ret = argv.map(fsm()).reduce(r, {})
    #special case to mix in empty global
    ret[GLOBAL] = {} unless ret.hasOwnProperty GLOBAL
    Object.freeze ret


parse_process_args = -> parse_args process.argv[2..]


construct_cmd = (args_list) ->
    """
    Constructs cmd from context object. (reverse to get_args_list)
    Ma be useful for passing arguments from existing context to spawn or
    exec functions.
    Returns cmd in list format [--arg1, command, --command_arg=val]
    """

    ret_cmd_vals = []
    arg1 = (arg) -> "-#{arg}"
    arg2 = (arg, val) -> "--#{arg}#{if val is undefined then '' else '=' + val}"
    format_arg = (arg, val) -> if val is true then arg1(arg) else arg2(arg, val)

    ret_cmd_vals.push(format_arg(arg, val)) for arg, val of args_list.global

    for command, args of filter_dict(args_list, (k, v) -> k not in ['global'])
        ret_cmd_vals.push "#{command}"
        ret_cmd_vals.push(format_arg(arg, val)) for arg, val of args

    ret_cmd_vals


module.exports = {parse_process_args, parse_args, construct_cmd}
