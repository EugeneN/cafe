{parse_args, construct_cmd} = require '../src/easy-opts'

SOME_SRC = "some_src"
GLOBAL_ARG = "global"

argv = ["--glob=#{GLOBAL_ARG}", 'compile', "--src=#{SOME_SRC}", "-f"]

exports.test_command_parsing =  (test) ->
    res_argv = parse_args argv
    test.ok(res_argv.compile?, "command was not parsed")
    test.done()

exports.test_command_arg_parsing = (test) ->
    res_argv = parse_args argv
    test.ok res_argv.compile.src is SOME_SRC, "command arg was not parsed"
    test.done()

exports.test_command_bool_parsing = (test) ->
    res_argv = parse_args argv
    test.ok res_argv.compile.f is true, "command bool arg was not parsed correctly"
    test.done()

exports.test_global_arguments_parsing = (test) ->
    res_argv = parse_args argv
    test.ok(res_argv.global.glob is GLOBAL_ARG, "global arg was not parsed correctly")
    test.done()

exports.test_construct_cmd = (test) ->
    obj = 
        global:
            glob: "glob_arg1_val"
        command1:
            f: true
            c1_arg: "c1_arg_val"
        command2:
            c2_arg: "c2_arg_val"

    expected_result = [
        "--glob=glob_arg1_val"
        "command1"
        "-f"
        "--c1_arg=c1_arg_val"
        "command2"
        "--c2_arg=c2_arg_val"
    ]

    result = construct_cmd obj
    expected_result.map (r) -> test.ok(r in result, "Expected #{r} to be in #{result}")
    test.done()