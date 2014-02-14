CONSOLE = [
    'log'
    'error'
    'debug'
    'warn'
]

# import this from monad
SKIP = true
NOSKIP = false
OK = null

estraverse = require 'estraverse'
esprima = require 'esprima'

replacement_src = "console.log('Fuck you')"
replacement_ast = (esprima.parse replacement_src, { tolerant: true, loc: false, range: false }).body[0].expression


is_console_log = (node) ->
    (node.type is 'CallExpression') \
        and (node.callee.type is 'MemberExpression') \
        and ((node.callee.object.type is 'Identifier') and (node.callee.object.name is 'console')) \
        and ((node.callee.property.type is 'Identifier') and (node.callee.property.name in CONSOLE))
    
# :: CafeApi -> BundleAst -> ErrorMonad SkipMonad BundleAst
mute = (cafe_api, ast) ->

    res_ast = estraverse.replace(ast, {
        enter: (node) ->
            if is_console_log node
                replacement_ast
            else
                node
    })

    # monadic value
    [OK, NOSKIP, res_ast]


mute.async = false


module.exports = mute