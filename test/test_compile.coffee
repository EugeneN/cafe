path = require 'path'
fs = require 'fs'
events = require 'events'
compile_target = require '../lib-js/targets/compile'
{run_target} = require '../lib-js/lib/target'
Cafe = require '../lib-js/cafe'

COMPILE_SRC = './fixtures/compile/cs/CSapp'
PUBLIC_DIR = './fixtures/compile/public'
SLUG = './slug.json'
SLUG_PATH = path.join COMPILE_SRC, SLUG

get_cafe = (setup) ->
    {ready} = cafe_factory()
    {go} = ready setup
    go

fb =
    say: console.log
    shout: console.log
    scream: console.log
    murmur: console.log
    whisper: console.log

null_fb = 
    say: ->
    shout: ->
    scream: ->
    murmur: ->
    whisper: ->

module.exports =
    setUp: (cb) ->
        js_file = path.resolve "./test/#{path.join PUBLIC_DIR, 'CSapp.js'}"
        if path.existsSync js_file
            fs.unlinkSync js_file
        cb?()

    tearDown: (cb) ->
        cb?()


    "Cafe compiles one module": (test) ->
        our_emitter = new events.EventEmitter

        mod_src = path.resolve "./test/fixtures/compile/cs/"
        mod_name = 'CSapp'
        js_path = path.resolve './test', PUBLIC_DIR

        args =
            global:
                debug: true
            compile:
                app_root: mod_src
                mod_name: mod_name
                js_path: js_path
                mod_suffix: '.'
                f: false
                t: false

        run_target 'compile', args, {emitter: our_emitter, fb: null_fb}, (err, res) ->
            exists = path.existsSync js_path, 'CSapp.js'

            test.ok exists, "compiled file was created"
            test.done()


    "compile without force": (test) ->
        our_emitter = new events.EventEmitter

        mod_src = path.resolve "./test/fixtures/compile/cs/"
        mod_name = 'CSapp'
        js_path = path.resolve './test', PUBLIC_DIR

        args =
            global:
                debug: true
            compile:
                app_root: mod_src
                mod_name: mod_name
                js_path: js_path
                mod_suffix: '.'
                f: false
                t: false

        our_emitter.on "COMPILE_MAYBE_SKIPPED", ->
            test.done()

        run_target 'compile', args, {emitter: our_emitter, fb: null_fb}, (err, res) ->
            run_target 'compile', args, {emitter: our_emitter, fb: null_fb}, (err, res) ->

    # "compile with force": (test) ->
    #     our_emitter = new events.EventEmitter
    #     mod_src = path.resolve "./test/fixtures/compile/cs/"
    #     mod_name = 'CSapp'
    #     js_path = path.resolve './test', PUBLIC_DIR

    #     args =
    #         global:
    #             debug: true
    #         compile:
    #             app_root: mod_src
    #             mod_name: mod_name
    #             js_path: js_path
    #             mod_suffix: '.'
    #             f: true
    #             t: false

    #     compile_target.run args, our_emitter, (err, result) ->
    #         our_emitter.on "COMPILE_MAYBE_FORCED", ->
    #             test.done()

    #         compile_target.run args, {emiter:our_emitter,fb:null_fb}, (err, result) ->
