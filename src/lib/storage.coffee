fs = require 'fs'

exports.put_to_tmp_storage = (key, data, cb) ->
    fs.writeFile key, data, (err) ->
        (cb err) if err
        cb? null, key
