path = require 'path'
fs = require 'fs'
{is_dir} = require './utils'
{ADAPTORS_PATH, ADAPTOR_FN, JS_EXT} = require '../defs'

module.exports = ->
    fn_pattern = "#{ADAPTOR_FN}#{JS_EXT}" 

    (fs.readdirSync ADAPTORS_PATH)\
       .map((p) -> path.join(ADAPTORS_PATH, p))\
       .filter((fn) -> (is_dir fn) and fn_pattern in fs.readdirSync fn)
       .map (d) ->
            require(path.join d, fn_pattern)
