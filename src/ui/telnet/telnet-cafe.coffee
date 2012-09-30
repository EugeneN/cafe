#!/usr/bin/env coffee

# a litle bit of housekeeping before going wild
Function::partial or= (part_args...) ->
    f = @
    (args...) -> f.apply(@, [part_args..., args...])

LOG_PREFIX = 'UI/Telnet>'
PASSWORD_PROMPT = "Password:"

Net = require 'net'
events = require 'events'

uuid = require 'node-uuid'
cafe_factory = require '../../cafe'
{is_array} = require "../../lib/utils"
logger = (require '../../lib/logger')()
pessimist = require '../../lib/pessimist'
{draw_logo} = require '../../lib/pictures'
ui = (require '../../lib/uilogger') LOG_PREFIX

{EVENT_CAFE_DONE, EXIT_SIGINT, TELNET_UI_HOST, TELNET_UI_PORT, UI_CMD_PREFIX,
 TELNET_CMD_MARKER, IAC_WILL_ECHO, IAC_WONT_ECHO, SIGINT, SIGTERM} = require '../../defs'

{green, yellow, red, blue, cyan} = logger
PROMPT = "\n#{cyan '?'}> "


START_TIME = new Date

process.on 'SIGINT', =>
    ui.say "SIGINT encountered, Cafe's closing"
    exit_cb EXIT_SIGINT

process.on 'SIGTERM', =>
    ui.say "SIGTERM encountered, Cafe's closing"
    exit_cb EXIT_SIGTERM

exit_cb = (status_code) ->
    ui.say "Cafe was open #{(new Date - START_TIME) / 1000}s"
    process.exit status_code

cafe_done_cb = (fb) ->
    (status_code) ->
        ui.say "Cafe run finished with status code #{status_code}"
        fb.prompt " "

parse_input_from_client = (data) ->
    clean_data = data.toString().replace /(\r\n|\n|\r)/gm, ""
    argv_like = ([null, null].concat clean_data.split ' ').filter (i) -> i isnt ''

    pessimist argv_like

match_data_type = (raw_data) ->
    if raw_data[0] is TELNET_CMD_MARKER
            ['telnet_control_seq', raw_data]
    else
        clean_data = raw_data.toString().replace /(\r\n|\n|\r)/gm, ''
        if clean_data[0] is UI_CMD_PREFIX
            ['ui_cmd', clean_data]
        else
            ['cafe_cmd', clean_data]

authenticate = ({password}) ->
    password is 'cafe'

handle_ui_cmd = (socket, fb, cmd, user_is_authenticated) ->
    switch cmd[1...]
        when 'bye'
            ui.say "User #{socket.remoteAddress} wants to quit"
            if user_is_authenticated
                socket.write blue "I'll miss you\n"
            socket.end yellow "Bye\n"

        when 'ping'
            fb.say cyan "Pong\n"
            fb.prompt ' '

        when 'help'
            fb.say """
                    Available commands:
                        /ping - say pong
                        /bye  - say goodbye
                        /help - show this help

                   """
            fb.prompt ' '

set_authenticated_socket_listener = ({socket, fb}) ->
    socket.on 'data', (data) ->
        [kind, clean_data] = match_data_type data
        ({
            telnet_control_seq: (clean_data) ->
                ui.say "Got control seq", clean_data

            ui_cmd: (clean_data) ->
                handle_ui_cmd socket, fb, clean_data, true

            cafe_cmd: (clean_data) ->
                args = parse_input_from_client clean_data
                ui.whisper "Got args from user #{socket.remoteAddress}:", args

                {ready} = cafe_factory()
                {go} = ready {exit_cb: (cafe_done_cb fb), fb: fb}
                go {args}

        }[kind]) clean_data


not_authenticated_listener = ({socket, fb}) ->
    # state is bad, but we need it for separate sockets.
    authenticated = false

    set_authenticated = ({password})->
        ui.say "User #{socket.remoteAddress} has been authenticated."

        fb.say "You have been authenticated successfully"
        fb.prompt "Type --help to get started"

        authenticated = true
        set_authenticated_socket_listener {socket, fb}

    (data) ->
        unless authenticated
            [kind, clean_data] = match_data_type data
            ({
                telnet_control_seq: (clean_data) ->
                    ui.say "Got control seq", clean_data

                ui_cmd: (clean_data) ->
                    handle_ui_cmd socket, fb, clean_data, authenticated

                cafe_cmd: (clean_data) ->
                    password = clean_data
                    ui.say "Password recieved from #{socket.remoteAddress}: '#{password}'"

                    if password and (authenticate {password})
                        fb.resetprompt()
                        set_authenticated {password}
                    else
                        fb.passprompt()

            }[kind]) clean_data

set_non_authenticated_socket_listener = ({socket, fb}) ->
    draw_logo fb

    fb.passprompt()
    socket.on 'data', not_authenticated_listener {socket, fb}

subscribe_console_logger = ->
    console_log_handler = (type, color) ->
        (message) -> console[type].apply console, message

    console_logger =
        say: console_log_handler 'log'
        shout: console_log_handler 'info'
        scream: console_log_handler 'error'
        whisper: console_log_handler 'error'
        murmur: (message) -> console.log message[0]

    logger.subscribe console_logger

subscribe_fb_logger = ->
    (socket) ->
        fb_log_handler = (log_prefix, color) ->
            (message...) ->
                prefix = if color then (color log_prefix) else ''
                msg = if is_array message then (message.join ' ') else message
                socket.write "#{prefix} #{msg}\n"

        my_LOG_PREFIX = [uuid.v4(), LOG_PREFIX].join '-'

        fb =
            say: fb_log_handler my_LOG_PREFIX, green
            shout: fb_log_handler my_LOG_PREFIX, yellow
            scream: fb_log_handler my_LOG_PREFIX, red
            whisper: fb_log_handler my_LOG_PREFIX, red
            murmur: fb_log_handler()
            prompt: (a) -> socket.write "#{a}#{PROMPT}"
            passprompt: (a) ->
                fb.raw IAC_WILL_ECHO
                fb.raw PASSWORD_PROMPT + " "
            resetprompt: ->
                fb.raw IAC_WONT_ECHO
            raw: (a) ->
                b = new Buffer a
                socket.write b

        # logger.subscribe fb
        # socket.on 'close', (had_error) -> logger.unsubscribe fb

        fb

module.exports = ->
    subscribe_console_logger()

    server = Net.createServer (socket) ->
        fb = subscribe_fb_logger() socket

        ui.say "New connection created for #{socket.remoteAddress}"
        set_non_authenticated_socket_listener {socket, fb}

    server.listen TELNET_UI_PORT, TELNET_UI_HOST
    ui.say "Server started on #{TELNET_UI_HOST}:#{TELNET_UI_PORT}"

