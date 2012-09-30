# Module for providing colored screen logs.
# Accepts prefix while requiring.
# Example:
# require('./logger') "MyPrefix>" will add prefix to all log methods.

# a litle bit of housekeeping before going wild
Function::partial or= (part_args...) ->
    f = @
    (args...) -> f.apply(@, [part_args..., args...])

default_prefix = 'Cafe>'

VERBOSE = true
DEBUG = false
NOCOLOR = false

SUBSCRIBERS = []

try
    color = require("ansi-color").set

    red = (s) -> if NOCOLOR then s else color s, 'red'
    green = (s) -> if NOCOLOR then s else color s, 'green'
    yellow = (s) -> if NOCOLOR then s else color s, 'yellow'
    blue = (s) -> if NOCOLOR then s else color s, 'blue'
    white = (s) -> if NOCOLOR then s else color s, 'white'
    cyan = (s) -> if NOCOLOR then s else color s, 'cyan'
catch e
    red = yellow = green = blue = white = cyan = (s) -> s


subscribe = (fb) ->
    SUBSCRIBERS.push fb

unsubscribe = (fb) ->
    new_subscribers = SUBSCRIBERS.filter (s) -> s isnt fb
    SUBSCRIBERS = new_subscribers

shutup = (m) ->
    switch m
        when on then VERBOSE = false
        when off then VERBOSE = true
        else VERBOSE

panic_mode = (m) ->
    switch m
        when on then DEBUG = true
        when off then DEBUG = false
        else DEBUG

nocolor = (m) ->
    switch m
        when on then NOCOLOR = true
        when off then NOCOLOR = false
        else NOCOLOR

log_type = (prefix, color) ->
    prefix or= default_prefix
    color prefix

LOG_PREFIX_DEBUG = (prefix) -> log_type "[DEBUG]#{prefix or default_prefix}", red
LOG_PREFIX_ERROR = (prefix) -> log_type prefix, red
LOG_PREFIX_INFO = (prefix) -> log_type prefix, green
LOG_PREFIX_WARN = (prefix) -> log_type prefix, yellow

ext_log = (type, msg) ->
    SUBSCRIBERS.map (s) ->
        s[type] msg

ext_info = ext_log.partial 'say'
ext_warn = ext_log.partial 'shout'
ext_error = ext_log.partial 'scream'
ext_debug = ext_log.partial 'whisper'
ext_murmur = ext_log.partial 'murmur'

info = (log_type) ->
    (prefix) ->
        (a...) ->
            if VERBOSE
                a.unshift log_type(prefix)
                # console.info.apply console, a
                ext_info a

warn = (log_type) ->
    (prefix) ->
        (a...) ->
            if VERBOSE
                a.unshift log_type(prefix)
                # console.info.apply console, a
                ext_warn a

error = (log_type) ->
    (prefix) ->
        (a...) ->
            a.unshift log_type(prefix)
            # console.error.apply console, a
            ext_error a

debug = (log_type) ->
    (prefix) ->
        (a...) ->
            if DEBUG
                a.unshift log_type(prefix)
                # console.error.apply console, a
                ext_debug a

murmur = (a...) ->
    if VERBOSE
        # console.log.apply console, a
        ext_murmur a

say = info LOG_PREFIX_INFO
shout = warn LOG_PREFIX_WARN
scream = error LOG_PREFIX_ERROR
whisper = debug LOG_PREFIX_DEBUG

module.exports = (prefix) ->
    say: say prefix
    shout: shout prefix
    scream: scream prefix
    whisper: whisper prefix
    murmur: murmur
    shutup: shutup
    panic_mode: panic_mode
    nocolor: nocolor
    red: red
    yellow: yellow
    green: green
    blue: blue
    white: white
    cyan: cyan
    subscribe: subscribe
    unsubscribe: unsubscribe

