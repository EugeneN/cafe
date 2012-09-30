fs           = require('fs')
eco          = require('eco')
uglify       = require('uglify-js')
path         = require('path')
compilers    = require('./compilers')
stitch       = require('../../assets/stitch')
Dependency   = require('./dependency')
Stitch       = require('./stitch')
{toArray}    = require('./utils')
logger = require('../lib/logger')
{say, shout, scream, whisper} = logger "Package>"


class Package
    constructor: (config = {}) ->
        @identifier = config.identifier
        @libs       = toArray(config.libs)
        @paths      = toArray(config.paths)
        @dependencies = toArray(config.dependencies)

    compileModules: ->
        @dependency or= new Dependency(@dependencies)
        @stitch     = new Stitch(@paths)
        @modules    = @dependency.resolve().concat(@stitch.resolve())
        stitch(identifier: @identifier, modules: @modules)

    compileLibs: ->
        (fs.readFileSync(path, 'utf8') for path in @libs).join("\n")

    compile: ->
        result = [@compileLibs(), @compileModules()].join("\n")
        result

    createServer: ->
        (env, callback) =>
            callback(200,
                'Content-Type': 'text/javascript',
                @compile())


module.exports =
    compilers:    compilers
    Package:        Package
    createPackage: (config) ->
        new Package(config)
