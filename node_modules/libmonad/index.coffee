# http://jsfiddle.net/n6GHF/10/

{identity, first, drop_while, is_function} = require 'libprotein'

is_null = (v...) ->
    if v.length is 0
        # special case: returning error literal when called without params
        null
    else
        v[0] is null

domonad = ({result, bind}, functions, init_value) ->
    f0 = bind (result init_value), functions[0]

    ([f0].concat functions[1...]).reduce (a, b) ->
        bind a, b

identity_m = ->
    result: identity

    bind: (mv, f) -> f mv


maybe_m = ({is_error}) ->
    zero: -> is_error() #?

    result: (v) -> v

    bind: (mv, f) ->
        if (is_error mv) then mv else (f mv)

    plus: (mvs...) ->
        first (drop_while is_error mvs)

maybe_t = (inner) ->
    result: (v) ->
        inner.result (v)

    bind: (mv, f) ->
        if (is_error mv) then mv else (inner.bind mv, f)

logger_m = (log_fn) ->
    result: (v) ->
        log_fn "Got value:", v
        v

    bind: (mv, f) ->
        log_fn "Going to call f(mv):", f, mv
        r = f mv
        log_fn "Got result:", r

logger_t = (inner, log_fn) ->
    result: (v) ->
        log_fn "Got value:", v
        r = inner.result v
        log_fn "Got inner monad's result value:", r
        r

    bind: (mv, f) ->
        log_fn "Going to call f(mv):", f, mv
        r = inner.bind mv, f
        log_fn "Got result:", r
        r

cont_m = ->
    result: (v) ->
        (c) -> c v

    bind: (mv, f) ->
        (c) ->
            mv ((v) -> ((f v) c))

cont_t = (inner) ->
    result: (v) ->
        (c) -> c (inner.result v)

    bind: (mv, f) ->
        (c) ->
            # pass decision on what to do with `f` and `v` to the inner monad
            # inner monads bind's result should return result, which we
            # should wrap into a function, which, when called
            # with a continuation, will return the actual result returned
            # from inner monad's wrapped function

            get_h = (v) ->
                inner_bind_res = inner.bind v, f

                # XXX: how to determine if `inner_bind_res` should be wrapped into a
                # continuation passed function?

                # theoretically `f` would probably always be a cont_m-compatible
                # function, that is:
                #
                #                    f: v -> f -> mv,
                #
                # where `mv` is cont_m's value.

                # in practice, it isn't
                if is_function inner_bind_res
                    inner_bind_res
                else
                    (c) -> c inner_bind_res

            mv ((v) -> (get_h v) c)


lift_sync = (arity, f) ->
    ''' Lifts a function:
    f: arg1 -> ... -> argN
    to a function:
    f1: (arg1 -> ... -> argN) -> cont
    '''
    (args...) ->
        (c) ->
            res = f args[0...arity]...
            c res

lift_async = (arity, f) ->
    ''' Lifts a function:
    f: arg1 -> ... -> argN -> cb
    to a function:
    f1: (arg1 -> ... argN) -> cont
    '''
    (args...) ->
        (c) ->
            f (args[0...arity-1].concat [c])...

module.exports = {
    domonad,
    identity_m,
    maybe_m, maybe_t,
    cont_m, cont_t,
    logger_m, logger_t,
    lift_sync, lift_async,
    is_null
}

#===============================================================================

#say = (m...) -> console.log m...
#
#log_result = (x...) -> say x...
#
#run = (c) -> c log_result
#
#lift_sync1 = (f, delay) ->
#    (x) ->
#        (c) ->
#            setTimeout(
#                -> c (f x)
#                delay
#            )
#
#
#SEX = 'sex'
#is_sex = (v...) ->
#    if v.length is 0
#        # special case: returning error literal when called without params
#        SEX
#    else
#        v[0] is SEX
#
#e1 = (x, cb) -> settimeout(300, cb(x * x))
#e2 = (x) -> say 2; x + 2; SEX
#e3 = (x) -> say 3; x + 0.25
#
#f1 = lift_sync1 e1, 100
#f2 = lift_sync1 e2, 200
#f3 = lift_sync1 e3, 300
#
##z = bind (bind (bind (result 3), f1), f2), f3
#
#y = domonad cont_m(), [f1, f2, f3, f1], 33
#
#cont_maybe = cont_t (maybe_m {is_error: is_sex})
#u = domonad cont_maybe, [f1, f2, f3], 33
#
##say u
##u say
#
##cont_identity = cont_t identity_m()
##v = domonad cont_identity, [f1, f2, f3], 33
#
##v say
