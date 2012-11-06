fs     = require('fs')
path     = require('path')
{is_dir, get_all_relative_files} = require('../utils')


parse = (data, values) ->
    data.replace /\{\{([^}]+)\}\}/g, (_, key) ->
        values[key]


make_skelethon = ({skelethon_path, result_path, values, fb}) ->
    throw "skelethon path is not set" unless skelethon_path
    throw "result path is not set" unless result_path

    (get_all_relative_files skelethon_path).map (_path) ->
        out = _path.replace skelethon_path, ''
        out = path.join result_path, out
        out = path.normalize out

        if (is_dir _path)
            fs.mkdirSync out, 0o0775
            fb?.say "Dirrectory created #{out}"
        else if (fs.existsSync out)
            throw "#{path} already exists"
        else
            data = parse(fs.readFileSync(_path, 'utf8'), values)
            fs.writeFileSync out, data
            fb?.say "File created #{out}"


module.exports = {
    make_skelethon
}
