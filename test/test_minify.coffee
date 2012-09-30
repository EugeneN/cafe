minify_target = require '../lib-js/targets/minify'
path = require 'path'
fs = require 'fs'
Cafe = require '../lib-js/cafe'
events = require 'events'

SOURCE_FILE = path.resolve './test/fixtures/minify/minify.js'
MINIFIED_FILE = path.resolve './test/fixtures/minify/minify-min.js'
MINIFIED_FILE_IN_MIN = path.resolve './test/fixtures/minify/min/minify-min.js'
MINIFY_DST_DIR = path.resolve './test/fixtures/minify/min'


module.exports = {
    setUp: (cb) ->
        if path.existsSync MINIFIED_FILE
            fs.unlinkSync MINIFIED_FILE
        cb?()


    tearDown: (cb) ->
        if path.existsSync MINIFIED_FILE
            fs.unlinkSync MINIFIED_FILE

        _min_file_in_dir_path = \
            path.join MINIFY_DST_DIR, path.basename(MINIFIED_FILE)

        if path.existsSync _min_file_in_dir_path
            fs.unlinkSync _min_file_in_dir_path
        cb?()
    

    "minifying one file without dst param" : (test) ->
        our_emitter = new events.EventEmitter

        args =
            minify:
                src: SOURCE_FILE
            
        minify_target.run args, our_emitter,  ->
            exists = path.existsSync MINIFIED_FILE
            test.ok exists, "minify file was not created"
            test.done()


    "minifying one file with dst param" : (test) ->
        our_emitter = new events.EventEmitter
        args =
            minify:
                src: SOURCE_FILE
                dst: MINIFY_DST_DIR

        minify_target.run args, our_emitter, ->
            exists = path.existsSync MINIFIED_FILE_IN_MIN
            test.ok exists, "minify file in dst folder was not created"
            test.done()


    "Minify folder" : (test) ->
        our_emitter = new events.EventEmitter
        args =
            minify:
                src: path.dirname(SOURCE_FILE)

        minify_target.run args, our_emitter, ->
            exists = path.existsSync MINIFIED_FILE
            test.ok exists, "minify file was not created"
            test.done()


    "skip minify without force flag" : (test) ->
        our_emitter = new events.EventEmitter
        args =
            minify:
                src: SOURCE_FILE

        our_emitter.on "MINIFY_SKIP", ->
            test.done()

        minify_target.run args, our_emitter, ->
            test.ok 'false', 'called from callback?'
            test.done()
                

    "Cafe minify run callback test" : (test) ->
        our_emitter = new events.EventEmitter
        args =
            global: {}
            minify:
                src: SOURCE_FILE
                f : true

        our_emitter.on "CAFE_DONE", ->
            test.done()

        cafe = new Cafe null, our_emitter, true
        cafe.run args


    "Minify with force flag" : (test) ->
        our_emitter = new events.EventEmitter
        args =
            global: {}
            minify:
                src: SOURCE_FILE
                f : true

        our_emitter.on "MINIFY_DONE", ->
            return test.done()

        minify_target.run args, our_emitter

    }
