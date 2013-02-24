{construct_module} = require '../src/lib/build/modules'

exports.test_modules_creation_from_string = (test) ->
    [err, parsed, module] = construct_module {module1:'module1.coffee'}
    test.ok parsed is true, "Module parsed indicator must be true"
    test.ok !err?, "Error occured #{err}"

    test.ok(module.name is 'module1'
            "Wrong module name, expected - module1, recieved - #{module.name}")

    test.ok(module.path is 'module1.coffee'
            "Wrong module path, exptected - module1.coffee, recieved - #{module.path}")

    test.ok(module.type is 'commonjs',
        "Wrong module type. Expected - commonjs, recieved - #{module.type}")
    test.ok module.location is 'fs'
    test.done()


exports.test_module_creation_from_object = (test) ->
    [err, parsed, module] = construct_module {module1: {path:'module1.coffee', type:'plainjs'}}
    test.ok parsed is true, "Module parsed indicator must be true"
    test.ok !err?, "Error occured #{err}"

    test.ok(module.name is 'module1'
            "Wrong module name, expected - module1, recieved - #{module.name}")

    test.ok(module.path is 'module1.coffee'
            "Wrong module path, exptected - module1.coffee, recieved - #{module.path}")

    test.ok module.type is 'plainjs'
    test.ok module.location is 'fs'
    test.done()


exports.test_module_creation_from_list = (test) ->
    [err, parsed, module] = construct_module {module1: ['module1.coffee', 'plainjs']}
    test.ok parsed is true, "Module parsed indicator must be true"
    test.ok !err?, "Error occured #{err}"

    test.ok(module.name is 'module1'
            "Wrong module name, expected - module1, recieved - #{module.name}")

    test.ok(module.path is 'module1.coffee'
            "Wrong module path, exptected - module1.coffee, recieved - #{module.path}")

    test.ok module.type is 'plainjs'
    test.ok module.location is 'fs'
    test.done()


