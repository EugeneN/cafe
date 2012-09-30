#!/usr/bin/env coffee

# a litle bit of housekeeping before going wild
Function::partial or= (part_args...) ->
    f = @
    (args...) -> f.apply(@, [part_args..., args...])

LOG_PREFIX = 'UI/CLI>'

cafe_factory = require '../../cafe'
pessimist = require '../../lib/pessimist'
{is_array} = require '../../lib/utils'
{draw_logo} = require '../../lib/pictures'
logger = (require '../../lib/logger') LOG_PREFIX
{EXIT_HELP, PR_SET_PDEATHSIG,
 EXIT_SIGINT, EXIT_SIGINT, SIGTERM, SIGINT} = require '../../defs'

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

module.exports = ->

    #logger.subscribe fb

    argv = pessimist process.argv

    logger.nocolor on if argv.global.hasOwnProperty 'nocolor'
    logger.shutup on if argv.global.hasOwnProperty 'shutup'
    logger.panic_mode on if argv.global.hasOwnProperty 'debug'

    draw_logo fb unless argv.global.hasOwnProperty 'nologo'

    {ready} = cafe_factory()
    {go} = ready {exit_cb, fb}
    go args: argv
