estraverse = require 'estraverse'

# import this from monad
SKIP = true
NOSKIP = false
OK = null

is_gettext = (node) ->
    (node.type is 'CallExpression') and ((node.callee.type is 'Identifier') and (node.callee.name is 'gettext'))

# :: CafeApi -> BundleAst -> ErrorMonad SkipMonad BundleAst
mute = (cafe_api, ast) ->

    res_ast = estraverse.replace(ast, {
        enter: (node) ->
            if is_gettext node
                cafe_api.ctx.fb.say "*** gettext found w/ args: #{node.arguments}"
            node
    })

    # monadic value
    [OK, NOSKIP, res_ast]


mute.async = false


module.exports = mute