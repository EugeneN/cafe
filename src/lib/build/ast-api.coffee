
map = (i, h) -> i.map h

mapT = (obj, handler, level) ->
    ret = []
    ret.push (handler.call null, obj, level)

    for own key, child of obj
        if typeof child is 'object' and child isnt null
            ret.concat (mapT child, handler, level+1)

    ret

join = (a, b) ->
    c = {}

    for own k, v of a
        c[k] = [v]

    for own k, v of b
        c[k] or= []
        if c[k]?[0] isnt v
            c[k].push v

    c



module.exports = {mapT, map, join}