# ******************** PESSIMIST ***************************
# Lib for parsing input args
#
# After parsing pessimist will return object with properties 
# that are appropriate to commands and command - attributes.
#
# Understands named (--arg=value) and boolean (-f) attributes.
# Accepts global parameters that are applied to other commands.
#
# If command has it's own parameter that is same as global than
# parameter is left not overwriten
#
# Example:
# lets assume we execute our bin/cafe file with such command:
#
#   bin/cafe  --src=uaprom   compile -f    minify --src=js-lib
#             \___global__|  \__command__|
#
# than somewhere in code:
#
#   pessimist = require 'pessimist'
#   args = pessimist(process.argv)
#
# than we have this in args:
#       { 
#           global: 
#               {
#                   src: 'uaprom'
#               }
#
#           compile :
#               { 
#                   src: 'uaprom' 
#                   f : true
#               }
#
#           minify : 
#               {
#                   src: 'js-lib'
#               }
#       }
#
# Command-attributes :
# Boolean:
#  -f              -is parsed as f:true
#  --attr=some     -is parsed as attr:some

{toArray} = require './utils'
GLOBAL = 'global'


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

get_args_list = (argv) -> 
    ret = argv[2..].map(fsm()).reduce(r, {})
    #special case to mix in empty global
    ret[GLOBAL] = {} unless ret.hasOwnProperty GLOBAL

    Object.freeze ret


module.exports = get_args_list
