domonad = ({result, bind}, functions) ->
    (init_value) ->
        f0 = bind (result init_value), functions[0]
        ([f0].concat functions[1...]).reduce (a, b) ->
            bind a, b


error_monad =
    bind: ([err, mv], mf) ->
        unless err then mf(mv) else [err, mv]

    result: (mv) -> [undefined, mv]


module.exports = {domonad, error_monad}