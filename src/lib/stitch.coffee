npath        = require('path')
fs           = require('fs')
compilers    = require('./compilers')
{modulerize} = require('./resolve')
{flatten}    = require('./utils')

{say, shout, scream, whisper} = (require '../lib/logger') "Stitch>"

class Stitch
    constructor: (@paths = []) ->
        @paths = (npath.resolve(path) for path in @paths)

    resolve: ->
        flatten(@walk(path) for path in @paths)

    # Private

    walk: (path, parent = path, result = []) ->
        return unless fs.existsSync path
        for child in fs.readdirSync(path)
            child = npath.join(path, child)
            stat = fs.statSync(child)
            if stat.isDirectory()
                @walk(child, parent, result)
            else
                module = new Module(child, parent)
                result.push(module) if module.valid()
        result

class Module
    constructor: (@filename, @parent) ->
        @ext = npath.extname(@filename).slice(1)
        @id  = modulerize(@filename.replace(@parent + '/', ''))

    compile: ->
        compilers[@ext](@filename)

    valid: ->
        !!compilers[@ext]


module.exports = Stitch