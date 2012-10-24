// Generated by CoffeeScript 1.3.3
(function() {
  var CB_SUCCESS, FILE_ENCODING, JS_PATTERN, SLUG_FN, add, and_, build_update_reenter_cmd, camelize, exists, expandPath, extend, filter_dict, flatten, fs, get_all_relative_files, get_mtime, get_opt, get_plugins, get_result_filename, has_ext, is_array, is_debug_context, is_dir, is_file, is_object, maybe_build, mtime_to_unixtime, newer, newest, or_, path, read_json_file, read_slug, reenter, say, scream, shout, spawn, toArray, trim, walk, whisper, _ref, _ref1,
    __slice = [].slice,
    __hasProp = {}.hasOwnProperty;

  fs = require('fs');

  path = require('path');

  spawn = require('child_process').spawn;

  _ref = (require('./logger'))('Utils>'), say = _ref.say, shout = _ref.shout, scream = _ref.scream, whisper = _ref.whisper;

  _ref1 = require('../defs'), JS_PATTERN = _ref1.JS_PATTERN, SLUG_FN = _ref1.SLUG_FN, FILE_ENCODING = _ref1.FILE_ENCODING, CB_SUCCESS = _ref1.CB_SUCCESS;

  read_slug = function(p) {
    var slug_fn;
    slug_fn = path.resolve(p, SLUG_FN);
    return JSON.parse(fs.readFileSync(slug_fn, FILE_ENCODING));
  };

  walk = function(dir, done) {
    var results;
    results = [];
    return fs.readdir(dir, function(err, list) {
      var pending;
      if (err) {
        return done(err);
      }
      pending = list.length;
      if (!pending) {
        return done(CB_SUCCESS, results);
      }
      return list.forEach(function(file) {
        file = path.join(dir, file);
        return fs.stat(file, function(err, stat) {
          if (stat && stat.isDirectory()) {
            return walk(file, function(err, res) {
              results = results.concat(res);
              if (!--pending) {
                return done(CB_SUCCESS, results);
              }
            });
          } else {
            results.push(file);
            if (!--pending) {
              return done(CB_SUCCESS, results);
            }
          }
        });
      });
    });
  };

  flatten = function(array, results) {
    var item, _i, _len;
    if (results == null) {
      results = [];
    }
    for (_i = 0, _len = array.length; _i < _len; _i++) {
      item = array[_i];
      if (Array.isArray(item)) {
        flatten(item, results);
      } else {
        results.push(item);
      }
    }
    return results;
  };

  toArray = function(value) {
    if (value == null) {
      value = [];
    }
    if (Array.isArray(value)) {
      return value;
    } else {
      return [value];
    }
  };

  is_array = function(v) {
    return Array.isArray(v);
  };

  mtime_to_unixtime = function(mtime_str) {
    return (new Date(mtime_str)).getTime();
  };

  get_mtime = function(filename) {
    var stat;
    stat = fs.statSync(filename);
    return mtime_to_unixtime(stat.mtime);
  };

  get_mtime.async = function(filename, cb) {
    return fs.stat(filename, function(err, stat) {
      if (err) {
        return cb(err);
      } else {
        return cb(mtime_to_unixtime(stat.mtime));
      }
    });
  };

  newest = function(l) {
    return Math.max.apply(Math, l);
  };

  maybe_build = function(build_root, built_file, cb) {
    var dst_max_mtime;
    dst_max_mtime = (function() {
      try {
        return get_mtime(built_file);
      } catch (e) {
        return -1;
      }
    })();
    return walk(build_root, function(err, results) {
      var should_recompile, src_max_mtime;
      if (results) {
        try {
          src_max_mtime = newest(results.map(function(filename) {
            return get_mtime(filename);
          }));
          should_recompile = dst_max_mtime < src_max_mtime;
        } catch (ex) {
          should_recompile = true;
        }
        if (should_recompile) {
          return typeof cb === "function" ? cb(true, built_file) : void 0;
        } else {
          return typeof cb === "function" ? cb(false, built_file) : void 0;
        }
      } else {
        return typeof cb === "function" ? cb(false, built_file) : void 0;
      }
    });
  };

  camelize = function(str) {
    return str.replace(/-|_+(.)?/g, function(match, chr) {
      if (chr) {
        return chr.toUpperCase();
      } else {
        return '';
      }
    }).replace(/^(.)?/, function(match, chr) {
      if (chr) {
        return chr.toUpperCase();
      } else {
        return '';
      }
    });
  };

  expandPath = function(_path, dir) {
    if (path.basename(_path === _path)) {
      _path = dir + _path;
    }
    return path.normalize(_path);
  };

  add = function() {
    var args, first, ret;
    args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    ' Polymorphic (kind of) function to add arbitrary number of arguments.\nDispatches types by the first argument.\nWhen adding objects, values for the same keys end up with the last one.\nExpect strange things to happen when adding values of different types.\n\nMost important: returns a new (frozen when possible) value,\nleaves arguments intact.';

    first = args[0];
    if (!first) {
      return first;
    } else if (Array.isArray(first)) {
      return args.reduce(function(a, b) {
        return a.concat(b);
      });
    } else if (first.toString() === '[object Object]') {
      ret = args.reduce(function(a, b) {
        var k, v;
        for (k in b) {
          if (!__hasProp.call(b, k)) continue;
          v = b[k];
          a[k] = v;
        }
        return a;
      }, {});
      return Object.freeze(ret);
    } else {
      return args.reduce(function(a, b) {
        return a + b;
      });
    }
  };

  filter_dict = function(d, filter_fn) {
    var k, ret, v;
    ret = {};
    for (k in d) {
      if (!__hasProp.call(d, k)) continue;
      v = d[k];
      if (filter_fn(k, v)) {
        ret[k] = v;
      }
    }
    return Object.freeze(ret);
  };

  is_debug_context = function(argv_or_ctx) {
    if (argv_or_ctx.hasOwnProperty('full_args')) {
      return argv_or_ctx.full_args.global.hasOwnProperty('debug');
    } else {
      return argv_or_ctx.global.hasOwnProperty('debug');
    }
  };

  read_json_file = function(filename) {
    if (fs.existsSync(filename)) {
      try {
        return Object.freeze(JSON.parse(fs.readFileSync(filename, FILE_ENCODING)));
      } catch (e) {
        scream("Error reading " + filename + ": " + e);
        whisper("" + e.stack);
        return void 0;
      }
    } else {
      return void 0;
    }
  };

  read_json_file.async = function(filename, cb) {
    return fs.readFile(filename, FILE_ENCODING, function(err, res) {
      if (err) {
        scream("Error reading file " + filename);
        return cb(err);
      } else {
        try {
          return cb(CB_SUCCESS, Object.freeze(JSON.parse(res)));
        } catch (e) {
          scream("Error parsing json file " + filename + ": " + e);
          whisper("" + e.stack);
          return cb(e);
        }
      }
    });
  };

  trim = function(s) {
    return s.replace(/^\s+|\s+$/g, '');
  };

  exists = function(fn) {
    return fs.existsSync(fn);
  };

  exists.async = function(fn, cb) {
    return fs.exists(fn, function(exs) {
      return cb(CB_SUCCESS, exs);
    });
  };

  is_dir = function(fn) {
    var stat;
    if (exists(fn)) {
      stat = fs.lstatSync(fn);
      return stat.isDirectory();
    } else {
      return false;
    }
  };

  is_dir.async = function(fn, cb) {
    return fs.lstat(fn, function(err, stat) {
      if (err) {
        return cb(err, false);
      } else {
        return cb(CB_SUCCESS, stat.isDirectory());
      }
    });
  };

  is_file = function(fn) {
    if (exists(fn)) {
      return !is_dir(fn);
    } else {
      return false;
    }
  };

  is_file.async = function(fn, cb) {
    return fs.lstat(fn, function(err, stat) {
      if (err) {
        return cb(err, false);
      } else {
        return cb(CB_SUCCESS, stat.isFile());
      }
    });
  };

  has_ext = function(fn, ext) {
    var re;
    re = new RegExp("\\." + ext + "$", 'i');
    return !!fn.match(re);
  };

  has_ext.async = function(fn, ext, cb) {
    return cb(CB_SUCCESS, has_ext(fn, ext));
  };

  get_plugins = function(base_dir) {
    var file, _i, _len, _ref2, _results;
    _ref2 = fs.readdirSync(base_dir);
    _results = [];
    for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
      file = _ref2[_i];
      if (JS_PATTERN.test(file)) {
        _results.push(file.replace(JS_PATTERN, ''));
      }
    }
    return _results;
  };

  is_object = function(v) {
    try {
      if (v.toString() === '[object Object]') {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  };

  extend = function(a, b) {
    var k, ret, v;
    if (!((is_object(a)) && (is_object(b)))) {
      throw "Arguments type mismatch: " + a + ", " + b;
    }
    ret = {};
    for (k in a) {
      v = a[k];
      ret[k] = v;
    }
    for (k in b) {
      v = b[k];
      ret[k] = ret[k] && is_object(ret[k]) ? extend(a[k], v) : v;
    }
    return ret;
  };

  newer = function(a, b) {
    try {
      return (get_mtime(a)) > (get_mtime(b));
    } catch (e) {
      return true;
    }
  };

  build_update_reenter_cmd = function(ctx) {
    var arg, arg1, arg2, args, cmd_args, command, format_arg, val, _ref2, _ref3;
    arg1 = function(arg) {
      return "-" + arg;
    };
    arg2 = function(arg, val) {
      return "--" + arg + (val === void 0 ? '' : '=' + val);
    };
    format_arg = function(arg, val) {
      if (val === true) {
        return arg1(arg);
      } else {
        return arg2(arg, val);
      }
    };
    cmd_args = ['--nologo'];
    _ref2 = ctx.global;
    for (arg in _ref2) {
      val = _ref2[arg];
      if (arg !== 'update') {
        cmd_args.push(format_arg(arg, val));
      }
    }
    _ref3 = filter_dict(ctx, function(k, v) {
      return k !== 'global';
    });
    for (command in _ref3) {
      args = _ref3[command];
      cmd_args.push("" + command);
      for (arg in args) {
        val = args[arg];
        cmd_args.push(format_arg(arg, val));
      }
    }
    return cmd_args;
  };

  reenter = function(ctx, cb) {
    var cmd_args, run;
    cmd_args = build_update_reenter_cmd(ctx);
    run = spawn(process.argv[1], cmd_args);
    run.stdout.on('data', function(data) {
      return say(("" + data).replace(/\n$/, ''));
    });
    run.stderr.on('data', function(data) {
      return scream(("" + data).replace(/\n$/, ''));
    });
    return run.on('exit', function(code) {
      shout("=== Re-enter finished with code " + code + " ===========");
      return typeof cb === "function" ? cb('stop') : void 0;
    });
  };

  get_opt = function(opt, bundle_opts, recipe_opts) {
    switch (bundle_opts != null ? bundle_opts[opt] : void 0) {
      case true:
        return true;
      case false:
        return false;
      default:
        return !!(recipe_opts != null ? recipe_opts[opt] : void 0);
    }
  };

  get_result_filename = function(source_fn, target_fn, src_ext, dst_ext) {
    "Creates destination file name for compiled file(if exists).\nelse return passed target_fn.\nParameters:\n    @source_fn : path to source file.\n    @target_fn : destination path for compiled result.\n    @src_ext : extension of source file.\n    @dst_ext : extension for destination file.";

    var name;
    if (is_dir(target_fn)) {
      name = ((path.basename(source_fn)).replace(new RegExp("" + src_ext + "$"), '')) + dst_ext;
      return path.resolve(target_fn, name);
    } else {
      return target_fn;
    }
  };

  and_ = function() {
    var args;
    args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    return args.reduce(function(a, b) {
      return !!a && !!b;
    });
  };

  or_ = function() {
    var args;
    args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    return args.reduce(function(a, b) {
      return !!a || !!b;
    });
  };

  get_all_relative_files = function(filepath) {
    "Gets all filenames recursively relative to filepath.";

    var files, next;
    files = [];
    next = function(dir) {
      var file, _i, _len, _ref2, _results;
      _ref2 = fs.readdirSync(dir);
      _results = [];
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        file = _ref2[_i];
        files.push(file = "" + dir + "/" + file);
        if (is_dir(file)) {
          _results.push(next(file));
        } else {
          _results.push(void 0);
        }
      }
      return _results;
    };
    next(filepath);
    return files;
  };

  module.exports = {
    read_slug: read_slug,
    walk: walk,
    flatten: flatten,
    toArray: toArray,
    mtime_to_unixtime: mtime_to_unixtime,
    get_mtime: get_mtime,
    newest: newest,
    maybe_build: maybe_build,
    camelize: camelize,
    expandPath: expandPath,
    add: add,
    filter_dict: filter_dict,
    is_debug_context: is_debug_context,
    read_json_file: read_json_file,
    trim: trim,
    exists: exists,
    is_dir: is_dir,
    is_file: is_file,
    has_ext: has_ext,
    get_plugins: get_plugins,
    is_object: is_object,
    extend: extend,
    newer: newer,
    is_array: is_array,
    reenter: reenter,
    get_opt: get_opt,
    get_result_filename: get_result_filename,
    get_all_relative_files: get_all_relative_files,
    and_: and_,
    or_: or_
  };

}).call(this);
