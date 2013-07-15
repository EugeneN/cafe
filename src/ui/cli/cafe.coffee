#!/usr/bin/env coffee

# a litle bit of housekeeping before going wild
Function::partial or= (part_args...) ->
    f = @
    (args...) -> f.apply(@, [part_args..., args...])

LOG_PREFIX = 'Cafe>'

path = require 'path'
events = require 'events'
growl = require 'growl'
{parse_args, parse_process_args} = require 'easy-opts'

cafe_factory = require '../../cafe'
{is_array} = require '../../lib/utils'
{draw_logo} = require '../../lib/pictures'
logger = (require '../../lib/logger') LOG_PREFIX

{
    EXIT_HELP, PR_SET_PDEATHSIG, EXIT_SIGINT,
    EXIT_SIGINT, SIGTERM, SIGINT, EXIT_SIGTERM,
    EXIT_OTHER_ERROR, EXIT_TARGET_ERROR, EVENT_CAFE_DONE,
    EXIT_SUCCESS, SUCCESS_ICO, FAILURE_ICO
} = require '../../defs'

{green, yellow, red} = logger

apply1 = (type, color) ->
    (a...) -> console[type].apply console, ([color LOG_PREFIX].concat a)

say = apply1 'log', green
shout = apply1 'info', yellow
scream = apply1 'error', red
whisper = apply1 'error', red
murmur = (a...) -> console.log.apply console, a

apply2 = (type, color) ->
    (a) ->
        prefix = if color then [color LOG_PREFIX] else []
        msg = prefix.concat (if (is_array a) then a else [a])
        console[type].apply console, msg

fb =
    say: apply2 'log', green
    shout: apply2 'info', yellow
    scream: apply2 'error', red
    whisper: apply2 'error', red
    murmur: apply2 'log'

START_TIME = new Date

process.on 'SIGINT', =>
    say "SIGINT encountered, Cafe's closing"
    exit_cb EXIT_SIGINT

process.on 'SIGTERM', =>
    say "SIGTERM encountered, Cafe's closing"
    exit_cb EXIT_SIGTERM

exit_cb = (status_code) ->
    fb.say "Cafe was open #{(new Date - START_TIME) / 1000}s"
    process.exit status_code

subscribe = (emitter) ->
    emitter.on 'NOTIFY_SUCCESS', (message) ->
        message or= "Cafe success :-)"
        growl message, {image: SUCCESS_ICO}

    emitter.on 'NOTIFY_FAILURE', (message) ->
        message or= "Cafe error :-("
        growl message, {image: FAILURE_ICO}

    emitter.on EVENT_CAFE_DONE, (status, error) ->
        switch status
            when EXIT_HELP
                undefined

            when EXIT_SUCCESS
                growl "Cafe success :)", {image: SUCCESS_ICO}

            when EXIT_TARGET_ERROR
                growl "Cafe target error: <#{error}>", {image: FAILURE_ICO}

            else
                growl "Cafe error: <#{error}>", {image: FAILURE_ICO}


module.exports = (args) ->

    argv = if args
        parse_args args
    else
        parse_process_args()

    logger.nocolor on if argv.global.hasOwnProperty 'nocolor'
    logger.shutup on if argv.global.hasOwnProperty 'shutup'
    logger.panic_mode on if argv.global.hasOwnProperty 'debug'

    is_growl = not argv.global.hasOwnProperty 'nogrowl'
    draw_logo fb unless argv.global.hasOwnProperty 'nologo'

    emitter = new events.EventEmitter

    (subscribe emitter) if is_growl

    {ready} = cafe_factory emitter
    {go} = ready {exit_cb, fb}
    go args: argv
