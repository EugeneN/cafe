{construct_module} = require '../src/lib/build/modules'
{NPM_MODULES_PATH} = require '../src/defs'

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

    [err2, parsed2, module2] = construct_module {module2: ["module2.coffee", ["module2_dep"]]}
    test.ok parsed2 is true, "Module parsed indicator must be true"
    test.ok !err2?, "Error occured #{err2}"
    test.ok(module2.name is 'module2'
            "Wrong module name, expected - module2, recieved - #{module2.name}")

    test.ok(module2.path is 'module2.coffee'
            "Wrong module path, exptected - module2.coffee, recieved - #{module2.path}")

    test.ok module2.type is 'commonjs', "Module type must be commonjs by default. Recieved - #{module2.type}"
    test.ok "module2_dep" in module2.deps, "Module2 must have module2_dep in dependencies"

    [err3, parsed3, module3] = construct_module {module3: ["module3.coffee", "plainjs", ["module3_dep"]]}
    test.ok parsed3 is true, "Module parsed indicator must be true"
    test.ok !err3?, "Error occured #{err3}"

    test.ok(module3.name is 'module3'
            "Wrong module name, expected - module3, recieved - #{module3.name}")

    test.ok(module3.path is 'module3.coffee'
            "Wrong module path, exptected - module2.coffee, recieved - #{module3.path}")

    test.ok module3.type is 'plainjs', "Module type must be plainjs. Recieved - #{module3.type}"
    test.ok "module3_dep" in module3.deps, "Module3 must have module2_dep in dependencies"

    test.done()


exports.test_npm_prefix_parse = (test) ->
    [err, skipped, module] = construct_module coffee: "npm://coffee-script_1@0.0.1"
    
    test.ok(
        module.prefix_meta.prefix is "npm" 
        "expected npm prefix , recieved #{module.prefix_meta.prefix}")

    test.ok(
        module.prefix_meta.npm_path is "coffee-script_1@0.0.1"
        "expected coffee-script_1@0.0.1 path - recieved #{module.prefix_meta.npm_path}"
        )

    test.ok(
        module.prefix_meta.version is "0.0.1"
        "expected 0.0.1 module version - recieved #{module.prefix_meta.version}"
        )

    test.ok(
        module.prefix_meta.npm_module_name is "coffee-script_1"
        "expected npm module name - coffee-script_1, recieved - #{module.prefix_meta.npm_module_name}"
        )

    test.ok(
        module.path is "#{NPM_MODULES_PATH}/#{module.prefix_meta.npm_module_name}"
        "expected #{NPM_MODULES_PATH}/#{module.prefix_meta.npm_module_name} module path - recieved #{module.path}"
        )

    [err, skipped, module] = construct_module coffee: "npm://coffee-script_1"

    test.ok(
        module.prefix_meta.npm_path is "coffee-script_1"
        "expected coffee-script_1 path - recieved #{module.prefix_meta.npm_path}"
        )

    test.ok(
        module.prefix_meta.npm_module_name is "coffee-script_1"
        "expected npm module name - coffee-script_1, recieved - #{module.prefix_meta.npm_module_name}"
        )

    test.done()



