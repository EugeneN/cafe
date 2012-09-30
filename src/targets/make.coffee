help = [
    """
    Creates a skeleton for a new module in the current working directory.

    Parameters:
        app <app_name>     - create a new app with the name 'app_name'
        controller <name>  - create a new controller
        model <name>       - create a new model
    """
]

path = require 'path'
fs = require 'fs'
Template = require '../lib/template'
{make_target} = require '../lib/target'
{camelize, expandPath, filter_dict} = require '../lib/utils'
{say, shout, scream, whisper} = require('../lib/logger') "Make>"


make_app = (name) ->
    throw "Bad name `#{name}`" unless name

    template = __dirname + "/../../assets/templates/app"
    values = {name}
    _path = path.normalize(name)

    throw(_path + " already exists") if fs.existsSync(_path)

    fs.mkdirSync _path, 0o0775
    (new Template(template, _path, values)).write()


make_controller = (name) ->
    throw "Bad name `#{name}`" unless name

    template = __dirname + "/../../assets/templates/controller.coffee"
    values = {name: camelize path.basename(name) }
    c_path = expandPath(name, "./app/controllers/") + ".coffee"

    (new Template(template, c_path, values)).write()


make_model = (name) ->
    throw "Bad name `#{name}`" unless name

    template = __dirname + "/../../assets/templates/model.coffee"
    values = {name: camelize path.basename(name) }
    c_path = expandPath(name, "./app/models/") + ".coffee"

    (new Template(template, c_path, values)).write()


maker = (ctx, cb) ->
    args = Object.keys(ctx.full_args).filter (k) -> k not in ['make', 'global']

    try
        switch args[0]
            when "app" then make_app args[1]
            when "controller" then make_controller args[1]
            when "model" then make_model args[1]
            else ctx.print_help()

    catch e
        ctx.fb.scream "Exception raised while making #{args[0]}: #{e}"
        scream "Exception raised while making #{args[0]}: #{e}"
        whisper "#{e.stack}"
        cb? 'target_error'

    cb? 'stop'


module.exports = make_target "make", maker, help, true
