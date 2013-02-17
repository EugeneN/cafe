path = require 'path'
{ADAPTER_FN, JS_EXT} = require '../src/defs'
fn_pattern = "#{ADAPTER_FN}.coffee"
{get_adapters} = require '../src/lib/adapter'
adapters_dir = path.resolve './test/fixtures/adapters'


exports.test_adapters_parse = (test) ->
    get_adapters.async adapters_dir, fn_pattern, (err, results) ->
        test.ok !err?, "Error recived #{err}"
        test.ok results?, "Adapters were not parsed"
        test.ok results.length is 2, "Must be 2 adapters - recieved #{results.length}"
        test.ok "adapter1" in results, "adapter1 must be in result #{results}"
        test.ok "adapter2" in results, "adapter2 must be in result #{results}"
        test.done()

