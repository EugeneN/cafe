"""
This module is used for generation basic modules structure.
"""

fs     = require('fs')
path     = require('path')
{is_dir, get_all_relative_files} = require('../utils')


parse = (data, values) ->
    data.replace /\{\{([^}]+)\}\}/g, (_, key) ->
        values[key]


make_skelethon = ({
    skelethon_path
    result_path
    values
    replace_file_names
    replace_dir_names
    fb
    }) ->

    """
    @skelethon_path: path where skelethon templates are placed.

    @result_path: path where we need to insert module skelethon.

    @values: replace values. Dict of values that will be inserted instead of
        placeholders in skelethon files.({'placeholder_name': value} 
        Placeholder's format - {{placeholder name}}

    @replace_file_names: if we need to replace some filenames we may 
        provide replace map.

    @replace_dir_names: dict with dir_name_to_replace: new_dirname
    """

    throw "skelethon path is not set" unless skelethon_path
    throw "result path is not set" unless result_path

    skelethon_path = path.normalize skelethon_path

    (get_all_relative_files skelethon_path).map (_path) ->
        out = _path.replace skelethon_path, ''

        for source_dir, dir_to_replace of replace_dir_names
            out = out.replace "/#{source_dir}", "/#{dir_to_replace}"

        dir = path.dirname out
        file = path.basename out
        if (replace_map?.hasOwnProperty file)
            out = path.join dir, replace_map[file]
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
