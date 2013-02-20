OK = undefined

error_m = -> # TODO: move this to libmonad
    is_error = ([err, val]) -> (err isnt OK) and (err isnt null)

    result: (v) -> [OK, v]

    bind: (mv, f) ->
        if (is_error mv) then mv else (f mv[1])


skip_or_error_m = ->
    is_skip = ([err, skip, val]) -> skip is true
    is_error = ([err, skip, val]) -> (err isnt OK) and (err isnt null)

    result: (v) -> [OK, false, v]

    bind: (mv, f) ->
        if (is_error mv) or (is_skip mv)
            mv
        else
            f mv[2]

module.exports = {error_m, skip_or_error_m, OK}