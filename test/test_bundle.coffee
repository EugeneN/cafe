{resolve_deps, toposort, build_bundle} = require '../src/lib/bundler'

GLOBAL_PARAM = "GLOB"
events = require 'events'


module.exports =
    "Topological sort works" : (test) ->
        modules = require './fixtures/bundle/toposort'
        output_list = toposort null, modules
        result_str = (m.name for m in output_list).join(',')
        test.equal(result_str, 'wife,grandpa,grandma,mother,father,sister,me,child')
        test.done()

    "Cyclic deps in toposort" : (test) ->
        one =
            name: 'one'
            deps: ['two']
        two =
            name: 'two'
            deps: ['one']
        three =
            name: 'three'
            deps: []

        test.throws(
            -> topological_sort([one, two, three]),
            "Cyclic dependency found: one, two",
            'Must throw error for cyclic deps'
        )
        test.done()

