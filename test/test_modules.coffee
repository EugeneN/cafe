{construct_module} = require '../src/lib/build/modules'

exports.test_modules_creation_from_string = (test) ->
    module = construct_module 'module1'
    test.ok module.name is 'module1'
    test.ok module.path is 'module1'
    test.ok module.type is 'commonjs'
    test.ok module.location is 'fs'
    test.done()


exports.test_module_creation_from_object = (test) ->
    module = construct_module {path:'module1', type:'plainjs'}
    test.ok module.name is 'module1'
    test.ok module.path is 'module1'
    test.ok module.type is 'plainjs'
    test.ok module.location is 'fs'
    test.done()


exports.test_module_creation_from_list = (test) ->
    module = construct_module ['module1', 'plainjs']
    test.ok module.name is 'module1'
    test.ok module.path is 'module1'
    test.ok module.type is 'plainjs'
    test.ok module.location is 'fs'
    test.done()


