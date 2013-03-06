// Generated by CoffeeScript 1.4.0
(function() {
  var CB_SUCCESS, CS_ADAPTOR_PATH_SUFFIX, CS_RUN_CONCURRENT, Compiler, SLUG_FN, TMP_BUILD_DIR_SUFFIX, add, and_, async, build_cs_mod, build_factory, extend, fs, get_mtime, get_paths, is_debug_context, is_dir, is_file, maybe_build, newest, or_, path, read_json_file, say, scream, shout, toArray, walk, whisper, _ref, _ref1, _ref2, _ref3;

  fs = require('fs');

  path = require('path');

  async = require('async');

  Compiler = require('../lib/sm_compiler');

  _ref = require('../lib/utils'), maybe_build = _ref.maybe_build, toArray = _ref.toArray, add = _ref.add, read_json_file = _ref.read_json_file, get_mtime = _ref.get_mtime, and_ = _ref.and_, or_ = _ref.or_;

  _ref1 = require('../lib/utils'), is_file = _ref1.is_file, is_dir = _ref1.is_dir, is_debug_context = _ref1.is_debug_context, extend = _ref1.extend, walk = _ref1.walk, newest = _ref1.newest;

  _ref2 = (require('../lib/logger'))("Adaptor/CsModule>"), say = _ref2.say, shout = _ref2.shout, scream = _ref2.scream, whisper = _ref2.whisper;

  _ref3 = require('../defs'), SLUG_FN = _ref3.SLUG_FN, TMP_BUILD_DIR_SUFFIX = _ref3.TMP_BUILD_DIR_SUFFIX, CS_ADAPTOR_PATH_SUFFIX = _ref3.CS_ADAPTOR_PATH_SUFFIX, CB_SUCCESS = _ref3.CB_SUCCESS, CS_RUN_CONCURRENT = _ref3.CS_RUN_CONCURRENT;

  build_cs_mod = function(ctx, cb) {
    var mod_src, slug_path, _ref4;
    _ref4 = get_paths(ctx), mod_src = _ref4.mod_src, slug_path = _ref4.slug_path;
    return async.parallel([
      (function(is_dir_cb) {
        return is_dir.async(mod_src, is_dir_cb);
      }), (function(is_file_cb) {
        return is_file.async(slug_path, is_file_cb);
      })
    ], function(err, res) {
      var modules, runner, seq;
      if (!err && (and_.apply(null, res))) {
        modules = [mod_src];
        seq = modules.map(function(module_path) {
          return build_factory(module_path, ctx);
        });
        runner = function(worker, cb) {
          return worker(cb);
        };
        if (CS_RUN_CONCURRENT) {
          return async.map(seq, runner, function(err, result) {
            return cb(err, result);
          });
        } else {
          return async.series(seq, function(err, result) {
            return cb(err, result);
          });
        }
      } else {
        ctx.fb.scream("Bad module source path `" + mod_src + "`, can't continue");
        return cb('target_error');
      }
    });
  };

  build_factory = function(mod_src, ctx) {
    var compiler_args, emitter, js_path, slug, slug_path, target_file, _ref4;
    _ref4 = get_paths(ctx), slug_path = _ref4.slug_path, js_path = _ref4.js_path;
    compiler_args = ctx.own_args;
    emitter = ctx.emitter;
    slug = read_json_file(slug_path);
    target_file = path.resolve(js_path, slug.jsPath);
    return function(cb) {
      var do_compile, new_cb;
      do_compile = function(do_tests, cb) {
        var compiler;
        compiler = new Compiler(mod_src, ctx, {
          "public": js_path
        });
        return compiler.build(function(err, result) {
          if (err) {
            ctx.fb.scream("Compile failed: " + err);
            return cb("Failed to compile spine app " + mod_src, err);
          } else {
            if (do_tests) {
              return compiler.build_tests(function(err, result) {
                return cb(err, result);
              });
            } else {
              return cb(err, result);
            }
          }
        });
      };
      new_cb = function(ev, cb, err, result) {
        emitter.emit(ev);
        return typeof cb === "function" ? cb(err, result) : void 0;
      };
      if (compiler_args.f) {
        return do_compile(compiler_args.t, function(err, result) {
          return new_cb("COMPILE_MAYBE_FORCED", cb, err, result);
        });
      } else {
        return maybe_build(mod_src, target_file, function(state, filename) {
          if (state) {
            return do_compile(compiler_args.t, function(err, result) {
              return new_cb("COMPILE_MAYBE_COMPILED", cb, err, result);
            });
          } else {
            ctx.fb.shout("" + mod_src + " still hot");
            emitter.emit("COMPILE_MAYBE_SKIPPED");
            return typeof cb === "function" ? cb(CB_SUCCESS, filename, "COMPILE_MAYBE_SKIPPED") : void 0;
          }
        });
      }
    };
  };

  get_paths = function(ctx) {
    var app_root, js_path, mod_src, mod_suffix, module_name, slug_path;
    app_root = path.resolve(ctx.own_args.app_root);
    module_name = ctx.own_args.mod_name;
    js_path = ctx.own_args.js_path;
    mod_suffix = ctx.own_args.mod_suffix;
    mod_src = ctx.own_args.src ? path.resolve(ctx.own_args.src) : path.resolve(app_root, mod_suffix || CS_ADAPTOR_PATH_SUFFIX, module_name);
    js_path = path.resolve(app_root, js_path || TMP_BUILD_DIR_SUFFIX);
    slug_path = path.resolve(mod_src, SLUG_FN);
    return {
      mod_src: mod_src,
      js_path: js_path,
      slug_path: slug_path
    };
  };

  module.exports = (function() {
    var make_adaptor, match;
    match = function(ctx) {
      var mod_src, slug_path, _ref4;
      _ref4 = get_paths(ctx), mod_src = _ref4.mod_src, slug_path = _ref4.slug_path;
      return (is_dir(mod_src)) && (is_file(slug_path));
    };
    match.async = function(ctx, cb) {
      var mod_src, slug_path, _ref4;
      _ref4 = get_paths(ctx), mod_src = _ref4.mod_src, slug_path = _ref4.slug_path;
      return async.parallel([
        (function(is_dir_cb) {
          return is_dir.async(mod_src, is_dir_cb);
        }), (function(is_file_cb) {
          return is_file.async(slug_path, is_file_cb);
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
      type = 'csmodule';
      get_deps = function(recipe_deps, cb) {
        var module_name, slug_path;
        module_name = ctx.own_args.mod_name;
        slug_path = get_paths(ctx).slug_path;
        return read_json_file.async(slug_path, function(err, slug) {
          var deps, group, group_deps, slug_deps, _ref4;
          if (err) {
            cb(err);
          }
          slug_deps = ((_ref4 = slug.recipe) != null ? _ref4.concat() : void 0) || [];
          for (group in recipe_deps) {
            deps = recipe_deps[group];
            if (group === module_name) {
              group_deps = deps.concat();
            }
          }
          slug_deps.concat(group_deps || []);
          return cb(CB_SUCCESS, slug_deps);
        });
      };
      harvest = function(cb, opts) {
        var args, js_path, mod_src, _ref4;
        if (opts == null) {
          opts = {};
        }
        _ref4 = get_paths(ctx), mod_src = _ref4.mod_src, js_path = _ref4.js_path;
        args = {
          full_args: {
            compile: {
              src: mod_src,
              js_path: js_path
            }
          },
          own_args: {
            src: mod_src,
            js_path: js_path
          }
        };
        return build_cs_mod(extend(ctx, extend(args, opts)), cb);
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
