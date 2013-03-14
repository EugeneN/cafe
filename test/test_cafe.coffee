cafe_factory = require '../lib-js/cafe'
GLOBAL_PARAM = "GLOB"
events = require 'events'
{EVENT_CAFE_DONE} = require '../lib-js/defs'

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


module.exports = {
    test05: "exit_cb can be passed in to cafe": (test) ->
        setup =
            emitter: new events.EventEmitter
            exit_cb: ->
                test.ok true, 'exit_cb has been called'
                test.done()
            fb: null_fb

        go = get_cafe setup
        go {args: {}}


    test06: "emitter can be passed in": (test) ->
        setup =
            emitter: new events.EventEmitter
            exit_cb: ->
            fb: null_fb

        setup.emitter.on EVENT_CAFE_DONE, ->
            test.ok true, 'emitter has been called'
            test.done()

        go = get_cafe setup
        go {args: {}}


    
}
