LOG_PREFIX = 'UI>'
{green, yellow, red, blue, cyan} = (require './logger')()
nocolor = (s) -> s

module.exports = (log_prefix) ->
    apply1 = (type, color) -> (a...) -> 
        console[type].apply console, ([color (log_prefix or LOG_PREFIX)].concat a)

    say = apply1 'log', cyan
    shout = apply1 'info', yellow
    scream = apply1 'error', red
    whisper = apply1 'error', red
    murmur = apply1 'log', nocolor

    {say, shout, scream, whisper, murmur}