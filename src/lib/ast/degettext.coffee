estraverse = require 'estraverse'
Gettext = require 'node-gettext'
fs = require 'fs'

gettext = new Gettext()
fileContents = fs.readFileSync('./uaprom/i18n/uk/LC_MESSAGES/uaprom.po');
gettext.addTextdomain("uk", fileContents);
gettext.textdomain("uk")

# import this from monad
SKIP = true
NOSKIP = false
OK = null

is_gettext = (node) ->
    node.type is 'CallExpression' \
    and ((node.callee.type is 'Identifier') and (node.callee.name is 'gettext')) \
    and ((node.arguments.length == 1) and (node.arguments[0].type == 'Literal'))

# :: CafeApi -> BundleAst -> ErrorMonad SkipMonad BundleAst
mute = (cafe_api, ast) ->

    res_ast = estraverse.replace(ast, {
        enter: (node) ->
            if is_gettext node
                cafe_api.ctx.fb.say "*** gettext found w/ args: #{node.arguments[0].value}"
                translation = gettext.gettext(node.arguments[0].value)
                return {
                    type: "Literal"
                    value: translation
                }
            node
    })

    # monadic value
    [OK, NOSKIP, res_ast]


mute.async = false


module.exports = mute