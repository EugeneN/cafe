esprima = require 'esprima'
{partial} = require '../utils'

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

is_require_define = (node) ->
    (node.type is 'MemberExpression') \
        and ((node.object.type is 'Identifier') and (node.object.name is 'require')) \
        and ((node.property.type is 'Identifier') and (node.property.name is 'define'))

gen_libprotocol_cache = (source) ->
    ast = esprima.parse source, { tolerant: true, loc: false, range: false }

    res =
        definitions: {}
        implementations: {}

    handle_protocols = (modname, node) ->
        if node and (node.type is 'Property') and (node.key?.name is 'protocols') and (node.value?.type is 'ObjectExpression')
            map node.value.properties, (p) ->
                def_or_impl = p.key.name
                map p.value.properties, (prop) ->
                    res[def_or_impl][prop.key.name] = modname

            node.value.properties

    map ast.body, (bi) ->
        # find require.define-d modules
        switch bi.type
            when 'ExpressionStatement'
                {type, callee} = bi.expression
                arguments_ = bi.expression.arguments # BTW: can't untuple into a reserved word

                if (type is 'CallExpression') and (is_require_define callee)
                    [ns, files] = arguments_
                    ns_name = ns.value

                    files.properties.map ({key, value}) ->
                        file_name = key.value
                        mod_name = [ns_name, file_name].filter((i) -> !!i).join '/'

                        mapT value.body, (partial handle_protocols, mod_name)

    join res.definitions, res.implementations


module.exports = {gen_libprotocol_cache}