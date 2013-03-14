path = require 'path'
app_root = path.resolve './test/fixtures/build_sequence/app/cs'
build_root = path.resolve './test/fixtures/build_sequence/app/public'
{init_build_sequence} = require '../src/lib/build/build_sequence'
{and_} = require '../src/lib/utils'
{ADAPTER_FN, JS_EXT} = require '../src/defs'
fn_pattern = "#{ADAPTER_FN}.coffee"
adapters_dir = path.resolve './test/fixtures/adapters'

is_present = (val) -> val? and (val.length > 0)

exports.test_init_build_sequence = (test) ->
    ctx = {own_args:{app_root, build_root}}

    init_build_sequence ctx, adapters_dir, fn_pattern, (err, results) ->
        {build_deps, adapters} = results
        test.ok results.hasOwnProperty("recipe"), "Recipe must be present in #{results}"
        test.ok is_present(build_deps), "Build deps must be present in #{results}"
        test.ok is_present(adapters), "Adapteres must be present in #{results}"
        test.done()
