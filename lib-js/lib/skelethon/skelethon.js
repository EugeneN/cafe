// Generated by CoffeeScript 1.3.3
(function() {
  "This module is used for generation basic modules structure.";

  var fs, get_all_relative_files, is_dir, make_skelethon, parse, path, _ref;

  fs = require('fs');

  path = require('path');

  _ref = require('../utils'), is_dir = _ref.is_dir, get_all_relative_files = _ref.get_all_relative_files;

  parse = function(data, values) {
    return data.replace(/\{\{([^}]+)\}\}/g, function(_, key) {
      return values[key];
    });
  };

  make_skelethon = function(_arg) {
    var fb, replace_dir_names, replace_file_names, result_path, skelethon_path, values;
    skelethon_path = _arg.skelethon_path, result_path = _arg.result_path, values = _arg.values, replace_file_names = _arg.replace_file_names, replace_dir_names = _arg.replace_dir_names, fb = _arg.fb;
    "@skelethon_path: path where skelethon templates are placed.\n\n@result_path: path where we need to insert module skelethon.\n\n@values: replace values. Dict of values that will be inserted instead of\n    placeholders in skelethon files.({'placeholder_name': value} \n    Placeholder's format - {{placeholder name}}\n\n@replace_file_names: if we need to replace some filenames we may \n    provide replace map.\n\n@replace_dir_names: dict with dir_name_to_replace: new_dirname";

    if (!skelethon_path) {
      throw "skelethon path is not set";
    }
    if (!result_path) {
      throw "result path is not set";
    }
    skelethon_path = path.normalize(skelethon_path);
    return (get_all_relative_files(skelethon_path)).map(function(_path) {
      var data, dir, dir_to_replace, file, out, source_dir;
      out = _path.replace(skelethon_path, '');
      for (source_dir in replace_dir_names) {
        dir_to_replace = replace_dir_names[source_dir];
        out = out.replace("/" + source_dir, "/" + dir_to_replace);
      }
      dir = path.dirname(out);
      file = path.basename(out);
      if (typeof replace_map !== "undefined" && replace_map !== null ? replace_map.hasOwnProperty(file) : void 0) {
        out = path.join(dir, replace_map[file]);
      }
      out = path.join(result_path, out);
      out = path.normalize(out);
      if (is_dir(_path)) {
        fs.mkdirSync(out, 0x1fd);
        return fb != null ? fb.say("Dirrectory created " + out) : void 0;
      } else if (fs.existsSync(out)) {
        throw "" + path + " already exists";
      } else {
        data = parse(fs.readFileSync(_path, 'utf8'), values);
        fs.writeFileSync(out, data);
        return fb != null ? fb.say("File created " + out) : void 0;
      }
    });
  };

  module.exports = {
    make_skelethon: make_skelethon
  };

}).call(this);
