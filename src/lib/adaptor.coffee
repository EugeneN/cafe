path = require 'path'
{is_file, is_dir, get_plugins} = require './utils'
{say, shout, scream, whisper} = (require './logger') "libadaptor>"

{ADAPTORS_PATH, ADAPTORS_LIB} = require '../defs'


module.exports = ->
    adaptors_names = get_plugins ADAPTORS_PATH

    adaptors = adaptors_names.map (a_name) ->
        try
            require path.join ADAPTORS_LIB, a_name
        catch e
            scream "Can't load adaptor '#{a_name}': #{e}"
            throw e
