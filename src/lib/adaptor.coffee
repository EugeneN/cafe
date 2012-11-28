path = require 'path'
fs = require 'fs'
{is_file, is_dir, get_plugins} = require './utils'
{say, shout, scream, whisper} = (require './logger') "libadaptor>"

{ADAPTORS_PATH, ADAPTOR_FN, ADAPTORS_LIB, JS_EXT} = require '../defs'

module.exports = ->
    fn_pattern = "#{ADAPTOR_FN}#{JS_EXT}" 

    (fs.readdirSync ADAPTORS_PATH)\
       .map((p) -> path.join(ADAPTORS_PATH, p))\
       .filter((fn) -> (is_dir fn) and fn_pattern in fs.readdirSync fn)
       .map (d) ->
            require(path.join d, fn_pattern)
