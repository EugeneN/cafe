{partial} = require '../utils'
esprima = require 'esprima'

# import this from monad
SKIP = true
NOSKIP = false
OK = null

is_require_define = (node) ->
    (node.type is 'MemberExpression') \
        and ((node.object.type is 'Identifier') and (node.object.name is 'require')) \
        and ((node.property.type is 'Identifier') and (node.property.name is 'define'))

# :: CafeApi -> BundleAst -> ErrorMonad SkipMonad BundleAst
gen_libprotocol_cache = (cafe_api, ast) ->
    res =
        definitions: {}
        implementations: {}

    handle_protocols = (modname, node) ->
        if node and (node.type is 'Property') and (node.key?.name is 'protocols') and (node.value?.type is 'ObjectExpression')
            cafe_api.map node.value.properties, (p) ->
                def_or_impl = p.key.name
                cafe_api.map p.value.properties, (prop) ->
                    res[def_or_impl][prop.key.name] = modname

            node.value.properties

    cafe_api.map ast.body, (bi) ->
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

                        cafe_api.mapT value.body, (partial handle_protocols, mod_name)

    cache_json = JSON.stringify (cafe_api.join res.definitions, res.implementations)
    cache_str = "window._libprotocol_cache = window._libprotocol_cache || []; window._libprotocol_cache.push(#{cache_json});"
    cache_ast = esprima.parse cache_str, { tolerant: true, loc: false, range: false }

    ast.body.unshift cache_ast

    # monadic value
    [OK, NOSKIP, ast]


gen_libprotocol_cache.async = false


module.exports = gen_libprotocol_cache