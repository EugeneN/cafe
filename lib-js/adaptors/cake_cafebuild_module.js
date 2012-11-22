// Generated by CoffeeScript 1.3.3
(function() {
  var CAFE_TARGET_FN_ENV_NAME, CAFE_TMP_BUILD_ROOT_ENV_NAME, CAKEFILE, CAKE_BIN, CAKE_TARGET, CB_SUCCESS, FILE_ENCODING, JS_EXT, NODE_PATH, TMP_BUILD_DIR_SUFFIX, and_, async, cs, exec, extend, fork, fs, get_mtime, get_paths, get_target_fn, has_ext, is_dir, is_file, maybe_build, newer, newest, partial, path, put_to_tmp_storage, say, scream, shout, spawn, stitch, stitch_sources, walk, whisper, _, _ref, _ref1, _ref2, _ref3,
    __slice = [].slice;

  fs = require('fs');

  path = require('path');

  cs = require('coffee-script');

  _ref = require('child_process'), exec = _ref.exec, spawn = _ref.spawn, fork = _ref.fork;

  _ref1 = (require('../lib/logger'))("Adaptor/Cakefile>"), say = _ref1.say, shout = _ref1.shout, scream = _ref1.scream, whisper = _ref1.whisper;

  _ref2 = require('../lib/utils'), maybe_build = _ref2.maybe_build, is_dir = _ref2.is_dir, is_file = _ref2.is_file, has_ext = _ref2.has_ext, and_ = _ref2.and_, get_mtime = _ref2.get_mtime, newer = _ref2.newer, walk = _ref2.walk, newest = _ref2.newest, extend = _ref2.extend;

  async = require('async');

  stitch_sources = require('../lib/stitcher').stitch_sources;

  put_to_tmp_storage = require('../lib/storage').put_to_tmp_storage;

  _ = require('underscore');

  _ref3 = require('../defs'), FILE_ENCODING = _ref3.FILE_ENCODING, TMP_BUILD_DIR_SUFFIX = _ref3.TMP_BUILD_DIR_SUFFIX, JS_EXT = _ref3.JS_EXT, CAKE_BIN = _ref3.CAKE_BIN, CAKE_TARGET = _ref3.CAKE_TARGET, NODE_PATH = _ref3.NODE_PATH, CAKEFILE = _ref3.CAKEFILE, CB_SUCCESS = _ref3.CB_SUCCESS, CAFE_TMP_BUILD_ROOT_ENV_NAME = _ref3.CAFE_TMP_BUILD_ROOT_ENV_NAME, CAFE_TARGET_FN_ENV_NAME = _ref3.CAFE_TARGET_FN_ENV_NAME;

  stitch = require('../lib/stitch');

  partial = function() {
    var args, fn;
    fn = arguments[0], args = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
    return _.bind.apply(_, [fn, null].concat(__slice.call(args)));
  };

  get_target_fn = function(js_path, app_root, target_fn) {
    if (js_path) {
      return path.resolve(js_path, target_fn);
    } else {
      return path.resolve(app_root, TMP_BUILD_DIR_SUFFIX, target_fn);
    }
  };

  get_paths = function(ctx) {
    var app_root, cakefile, js_path, mod_src, module_name, src, target_fn, target_full_fn, tmp_build_root;
    app_root = path.resolve(ctx.own_args.app_root);
    module_name = ctx.own_args.mod_name;
    src = ctx.own_args.src;
    js_path = ctx.own_args.js_path;
    mod_src = src || path.resolve(app_root, module_name);
    cakefile = path.resolve(mod_src, CAKEFILE);
    target_fn = path.basename(module_name + JS_EXT);
    target_full_fn = get_target_fn(js_path, app_root, target_fn);
    tmp_build_root = js_path || path.resolve(app_root, TMP_BUILD_DIR_SUFFIX);
    return {
      mod_src: mod_src,
      cakefile: cakefile,
      target_fn: target_fn,
      target_full_fn: target_full_fn,
      tmp_build_root: tmp_build_root
    };
  };

  module.exports = (function() {
    var make_adaptor, match;
    match = function(ctx) {
      var cakefile, mod_src, _ref4;
      _ref4 = get_paths(ctx), mod_src = _ref4.mod_src, cakefile = _ref4.cakefile;
      return (is_dir(mod_src)) && (is_file(cakefile));
    };
    match.async = function(ctx, cb) {
      var cakefile, mod_src, _ref4;
      _ref4 = get_paths(ctx), mod_src = _ref4.mod_src, cakefile = _ref4.cakefile;
      return async.parallel([
        (function(is_dir_cb) {
          return is_dir.async(mod_src, is_dir_cb);
        }), (function(is_file_cb) {
          return is_file.async(cakefile, is_file_cb);
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
      type = 'cakefile';
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
      harvest = function(harvest_cb, opts) {
        var check_maybe_do, do_cake, done, mod_src, target_fn, target_full_fn, tmp_build_root, _ref4;
        if (opts == null) {
          opts = {};
        }
        _ref4 = get_paths(ctx), mod_src = _ref4.mod_src, target_full_fn = _ref4.target_full_fn, target_fn = _ref4.target_fn, tmp_build_root = _ref4.tmp_build_root;
        check_maybe_do = function(cb) {
          return maybe_build(mod_src, target_full_fn, function(changed, filename) {
            if (changed || (extend(ctx, opts)).own_args.f) {
              return cb();
            } else {
              return cb('MAYBE_SKIP');
            }
          });
        };
        do_cake = function(cb) {
          var child, sources;
          sources = null;
          opts = {
            cwd: mod_src,
            env: process.env,
            silent: true
          };
          child = fork(CAKE_BIN, [CAKE_TARGET], opts);
          child.on('message', function(m) {
            child.kill();
            return sources = JSON.parse(m);
          });
          return child.on('exit', function(status_code) {
            if (sources) {
              return cb(CB_SUCCESS, sources);
            } else {
              return cb('fork_error', status_code);
            }
          });
        };
        done = function(err, res) {
          switch (err) {
            case null:
              ctx.fb.say("Cake module " + mod_src + " was brewed");
              return harvest_cb(CB_SUCCESS, target_full_fn);
            case "MAYBE_SKIP":
              ctx.fb.shout("maybe skipped");
              return harvest_cb(null, target_full_fn);
            default:
              ctx.fb.scream("Error during compilation of Cake module " + mod_src + " err - " + err);
              return harvest_cb(err, res);
          }
        };
        return async.waterfall([check_maybe_do, do_cake, stitch_sources, partial(put_to_tmp_storage, target_full_fn)], done);
      };
      last_modified = function(cb) {
        var mod_src;
        mod_src = get_paths(ctx).mod_src;
        return walk(mod_src, function(err, results) {
          var max_time;
          if (results) {
            max_time = (function() {
              try {
                return newest(results.map(function(filename) {
                  return get_mtime(filename);
                }));
              } catch (ex) {
                return 0;
              }
            })();
            return cb(CB_SUCCESS, max_time);
          } else {
            return cb(CB_SUCCESS, 0);
          }
        });
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
