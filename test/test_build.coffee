cafe_factory = require '../lib-js/cafe'
events = require 'events'
path = require 'path'
single_file_app_root = "./test/fixtures/build/single_file_modules"
slug_module_app_root = "./test/fixtures/build/slug_modules_build"
formula = "recipe.yaml"

fb =
    say: console.log
    shout: console.log
    scream: console.log
    murmur: console.log
    whisper: console.log

get_cafe = (setup) ->
    {ready} = cafe_factory()
    {go} = ready setup
    go

module.exports =
    "Test single files bundling" : (test) ->
        args =
            build:
                app_root: path.join single_file_app_root, "cs"
                build_root: path.join single_file_app_root, "public"
                formula: "recipe.yaml"
                f: true
            global:
                nologo: true

        setup =
            emitter: new events.EventEmitter
            exit_cb: (status) ->
                test.ok status is 0, 'build was successfull'
                test.done()
            fb: fb

        go = get_cafe setup
        go {args}


    "Test slug modules build" : (test) ->
        args =
            build:
                app_root: path.join slug_module_app_root, "cs"
                build_root: path.join slug_module_app_root, "public"
                formula: "recipe.yaml"
                f: true
            global:
                nologo: true

        setup =
            emitter: new events.EventEmitter
            exit_cb: (status) ->
                test.ok status is 0, 'build was successfull'
                test.done()
            fb: fb

        go = get_cafe setup
        go {args}