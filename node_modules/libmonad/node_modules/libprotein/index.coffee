module.exports =
    partial: (f, partial_args...) -> (args...) -> f (partial_args.concat args)...

    complement: (f) -> (args...) -> !(f args...)

    compose2: (f, g) -> (args...) -> f g args...

    first: (s) -> s[0]

    identity: (x) -> x

    drop_while: (f, s) ->
        for i in s
            return i unless (f i)

    is_function: (v) -> typeof v is 'function'

    is_array: (v) -> Array.isArray v

    is_object: (v) ->
        # FIXME
        if is_array v
            false
        else
            v instanceof {}.constructor

    bool: (v) ->
        # FIXME
        if (is_array v)
            !!v.length
        else if (is_object v)
            !!(Object.keys(v).length)
        else
            !!v
