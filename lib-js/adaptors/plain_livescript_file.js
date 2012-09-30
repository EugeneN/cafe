// Generated by CoffeeScript 1.3.3
(function() {
  var CB_SUCCESS, FILE_ENCODING, JS_EXT, LIVESCRIPT_EXT, TMP_BUILD_DIR_SUFFIX, and_, async, cs, exec, fs, get_mtime, get_paths, get_target_fn, has_ext, is_file, newer, path, say, scream, shout, whisper, _ref, _ref1, _ref2;

  fs = require('fs');

  path = require('path');

  cs = require('coffee-script');

  exec = require('child_process').exec;

  _ref = require('../lib/utils'), is_file = _ref.is_file, has_ext = _ref.has_ext, get_mtime = _ref.get_mtime, newer = _ref.newer, and_ = _ref.and_;

  _ref1 = (require('../lib/logger'))("Adaptor/livescript>"), say = _ref1.say, shout = _ref1.shout, scream = _ref1.scream, whisper = _ref1.whisper;

  async = require('async');

  _ref2 = require('../defs'), FILE_ENCODING = _ref2.FILE_ENCODING, TMP_BUILD_DIR_SUFFIX = _ref2.TMP_BUILD_DIR_SUFFIX, LIVESCRIPT_EXT = _ref2.LIVESCRIPT_EXT, JS_EXT = _ref2.JS_EXT, CB_SUCCESS = _ref2.CB_SUCCESS;

  get_target_fn = function(app_root, module_name) {
    return path.resolve(app_root, TMP_BUILD_DIR_SUFFIX, (module_name.replace(new RegExp("" + LIVESCRIPT_EXT + "$"), '')) + JS_EXT);
  };

  get_paths = function(ctx) {
    var app_root, module_name;
    app_root = path.resolve(ctx.own_args.app_root);
    module_name = ctx.own_args.mod_name;
    return {
      source_fn: path.resolve(app_root, module_name),
      target_fn: get_target_fn(path.resolve(ctx.own_args.app_root), path.basename(module_name))
    };
  };

  module.exports = (function() {
    var make_adaptor, match;
    match = function(ctx) {
      var source_fn;
      source_fn = get_paths(ctx).source_fn;
      return (is_file(source_fn)) && (has_ext(source_fn, LIVESCRIPT_EXT));
    };
    match.async = function(ctx, cb) {
      var source_fn;
      source_fn = get_paths(ctx).source_fn;
      return async.parallel([
        (function(is_file_cb) {
          return is_file.async(source_fn, is_file_cb);
        }), (function(is_file_cb) {
          return has_ext.async(source_fn, LIVESCRIPT_EXT, is_file_cb);
        })
      ], function(err, res) {
        if (!err && (and_.apply(null, res))) {
          return cb(CB_SUCCESS, true);
        } else {
          return cb(CB_SUCCESS, false);
        }
      });
    };
    make_adaptor = function(ctx) {
      var get_deps, harvest, last_modified, type;
      type = 'plain_livescript_file';
      get_deps = function(recipe_deps, cb) {
        var deps, group, group_deps, module_name;
        module_name = ctx.own_args.mod_name;
        for (group in recipe_deps) {
          deps = recipe_deps[group];
          if (group === module_name) {
            group_deps = deps.concat();
          }
        }
        return cb(CB_SUCCESS, group_deps || []);
      };
      harvest = function(cb) {
        var source_fn, target_fn, _ref3;
        _ref3 = get_paths(ctx), source_fn = _ref3.source_fn, target_fn = _ref3.target_fn;
        if (newer(source_fn, target_fn)) {
          return exec("" + LIVESCRIPT_BIN + " -p -b -c " + source_fn + " > " + target_fn, function(err, stdout, stderr) {
            if (err) {
              ctx.fb.scream("Error compiling " + source_fn + ": " + err);
              if (stdout) {
                ctx.fb.scream("STDOUT: " + stdout);
              }
              if (stderr) {
                ctx.fb.scream("STDERR: " + stderr);
              }
              return cb(CB_SUCCESS, void 0);
            } else {
              ctx.fb.say("Livescript " + source_fn + " brewed");
              if (stdout) {
                ctx.fb.say("STDOUT: " + stdout);
              }
              if (stderr) {
                ctx.fb.say("STDERR: " + stderr);
              }
              return cb(CB_SUCCESS, target_fn);
            }
          });
        } else {
          ctx.fb.shout("Livescript " + source_fn + " still hot");
          return cb(CB_SUCCESS, target_fn, "COMPILE_MAYBE_SKIPPED");
        }
      };
      last_modified = function(cb) {
        var source_fn;
        source_fn = get_paths(ctx).source_fn;
        return cb(CB_SUCCESS, get_mtime(source_fn));
      };
      return {
        type: type,
        get_deps: get_deps,
        harvest: harvest,
        last_modified: last_modified
      };
    };
    return {
      match: match,
      make_adaptor: make_adaptor
    };
  })();

}).call(this);
