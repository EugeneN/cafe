async = require 'async'

async_compose_wrapper = (fn) ->
    (args...) ->
        [fn_args, cb] = [args[...-1], args[-1...][0]]
        try
            cb null, fn(fn_args...)
        catch err
            cb "#{err}"


waterfall_lift = (fns, init_val, exit_cb) ->
    mod_chain = fns.map (f) -> async_compose_wrapper f
    mod_chain.unshift (cb) -> cb null, init_val
    async.waterfall mod_chain, exit_cb


module.exports = {async_compose_wrapper, waterfall_lift}

