pessimist = require '../lib-js/lib/pessimist'

SOME_SRC = "some_src"
GLOBAL_ARG = "global"

argv = ['node', 'some/path/', "--glob=#{GLOBAL_ARG}", 'compile', "--src=#{SOME_SRC}", "-f"]

exports.test_command_parsing =  (test) ->
    res_argv = pessimist argv
    test.ok(res_argv.compile?, "command was not parsed")
    test.done()

exports.test_command_arg_parsing = (test) ->
    res_argv = pessimist argv
    test.ok res_argv.compile.src is SOME_SRC, "command arg was not parsed"
    test.done()

exports.test_command_bool_parsing = (test) ->
    res_argv = pessimist argv
    test.ok res_argv.compile.f is true, "command bool arg was not parsed correctly"
    test.done()

exports.test_global_arguments_parsing = (test) ->
    res_argv = pessimist argv
    test.ok(res_argv.global.glob is GLOBAL_ARG, "global arg was not parsed correctly")
    test.done()
