path = require 'path'
fs = require 'fs'
SLUG_ASSETS_PATH = './cs_module_build_adaptor/slug_module'
SPINE_ASSETS_PATH = './cs_module_build_adaptor/spine_app'

camelize = (str) ->
    str.replace(/-|_+(.)?/g, (match, chr) ->
        if chr
            chr.toUpperCase()
        else
            ''
    ).replace(/^(.)?/, (match, chr) ->
        if chr
            chr.toUpperCase()
        else
            ''
    )

expandPath = (_path, dir) ->
    if path.basename _path is _path
        _path = dir + _path

    path.normalize _path


exports.module = (ctx_args) ->
    name = ctx_args[1]
    throw "Need module name" unless name
    values = {name: path.basename(name)}
    _path = path.normalize(name)
    throw(_path + " already exists") if fs.existsSync(_path)

    fs.mkdirSync _path, 0o0775

    skelethon_path: SLUG_ASSETS_PATH
    result_path: _path
    values: values


exports.spinecontroller = () ->
    throw "Bad name `#{name}`" unless name

    template = "#{SPINE_ASSETS_PATH}/controller.coffee"
    values = {name: camelize path.basename(name) }
    c_path = expandPath(name, "./app/controllers/") + ".coffee"

    skelethon_path: template
    result_path: c_path
    values: values


exports.spinemodel = (ctx_args) ->
    name = ctx_args[1]
    throw "Bad name `#{name}`" unless name
    template = "#{SPINE_ASSETS_PATH}/model.coffee"
    values = {name: camelize path.basename(name) }
    c_path = expandPath(name, "./app/models/") + ".coffee"

    skelethon_path: template
    result_path: c_path
    values: values


exports.spineapp = (ctx_args) ->
    name = ctx_args[1]
    throw "Bad name `#{name}`" unless name

    template = "#{SPINE_ASSETS_PATH}/app"
    values = {name: path.basename(name)}
    _path = path.normalize(name)
    throw(_path + " already exists") if fs.existsSync(_path)
    fs.mkdirSync _path, 0o0775

    skelethon_path: template
    result_path: _path
    values: values
