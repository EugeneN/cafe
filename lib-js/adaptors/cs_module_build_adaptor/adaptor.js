// Generated by CoffeeScript 1.4.0
(function() {
  var CAFE_DIR, CB_SUCCESS, CS_ADAPTOR_PATH_SUFFIX, CS_RUN_CONCURRENT, SLUG_FN, TMP_BUILD_DIR_SUFFIX, add, and_, async, build_cs_mod, build_factory, extend, fn_without_ext, fs, get_mtime, get_paths, is_debug_context, is_dir, is_file, maybe_build, newest, or_, path, read_json_file, toArray, walk, _ref, _ref1;

  fs = require('fs');

  path = require('path');

  async = require('async');

  _ref = require('../../lib/utils'), maybe_build = _ref.maybe_build, toArray = _ref.toArray, add = _ref.add, read_json_file = _ref.read_json_file, get_mtime = _ref.get_mtime, and_ = _ref.and_, or_ = _ref.or_, is_file = _ref.is_file, is_dir = _ref.is_dir, is_debug_context = _ref.is_debug_context, extend = _ref.extend, walk = _ref.walk, newest = _ref.newest;

  _ref1 = require('../../defs'), SLUG_FN = _ref1.SLUG_FN, TMP_BUILD_DIR_SUFFIX = _ref1.TMP_BUILD_DIR_SUFFIX, CS_ADAPTOR_PATH_SUFFIX = _ref1.CS_ADAPTOR_PATH_SUFFIX, CB_SUCCESS = _ref1.CB_SUCCESS, CS_RUN_CONCURRENT = _ref1.CS_RUN_CONCURRENT, CAFE_DIR = _ref1.CAFE_DIR;

  fn_without_ext = function(filename) {
    var ext_length;
    ext_length = (path.extname(filename)).length;
    return filename.slice(0, -ext_length);
  };

  build_cs_mod = function(ctx, cb) {
    var mod_src, slug_path, _ref2;
    _ref2 = get_paths(ctx), mod_src = _ref2.mod_src, slug_path = _ref2.slug_path;
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
            return cb(err, result[0]);
          });
        } else {
          return async.series(seq, function(err, result) {
            return cb(err, result[0]);
          });
        }
      } else {
        ctx.fb.scream("Bad module source path `" + mod_src + "`, can't continue");
        return cb('target_error');
      }
    });
  };

  build_factory = function(mod_src, ctx) {
    var slug, slug_path;
    slug_path = get_paths(ctx).slug_path;
    slug = read_json_file(slug_path);
    return function(cb) {
      var do_compile;
      do_compile = function(cb) {
        var coffee, compiler, eco, js, sources, _ref2;
        slug = ctx.cafelib.utils.read_slug(mod_src, ctx.cafelib.utils.slug);
        slug.paths = slug.paths.map(function(p) {
          return path.resolve(path.join(mod_src, p));
        });
        _ref2 = require('../../lib/compiler/compilers'), coffee = _ref2.coffee, eco = _ref2.eco, js = _ref2.js;
        compiler = ctx.cafelib.make_compiler([coffee, eco, js]);
        sources = slug.paths.map(function(slug_path) {
          var paths;
          paths = ctx.cafelib.utils.get_all_relative_files(slug_path, null, /^[^\.].+\.coffee$|^[^\.].+\.js$|^[^\.].+\.eco$/i);
          try {
            return (compiler.compile(paths)).map(function(_arg) {
              var p, source;
              p = _arg.path, source = _arg.source;
              return {
                filename: fn_without_ext(path.relative(slug_path, p)),
                source: source,
                type: "commonjs"
              };
            });
          } catch (e) {
            ctx.fb.scream("Module compilation error. Module - " + mod_src + ". Error - " + e);
            return cb('compile_error');
          }
        });
        return cb(null, {
          sources: ctx.cafelib.utils.flatten(sources),
          ns: path.basename(mod_src),
          mod_src: mod_src
        });
      };
      return do_compile(function(err, result) {
        return typeof cb === "function" ? cb(err, result) : void 0;
      });
    };
  };

  get_paths = function(ctx) {
    var app_root, mod_src, module_name, slug_path;
    app_root = path.resolve(ctx.own_args.app_root);
    module_name = ctx.own_args.mod_name;
    mod_src = ctx.own_args.src ? path.resolve(ctx.own_args.src) : path.resolve(app_root, module_name);
    slug_path = path.resolve(mod_src, SLUG_FN);
    return {
      mod_src: mod_src,
      slug_path: slug_path
    };
  };

  module.exports = (function() {
    var make_adaptor, make_skelethon, match;
    match = function(ctx) {
      var mod_src, slug_path, _ref2;
      _ref2 = get_paths(ctx), mod_src = _ref2.mod_src, slug_path = _ref2.slug_path;
      return (is_dir(mod_src)) && (is_file(slug_path));
    };
    match.async = function(ctx, cb) {
      var mod_src, slug_path, _ref2;
      _ref2 = get_paths(ctx), mod_src = _ref2.mod_src, slug_path = _ref2.slug_path;
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
          var deps, group, group_deps, slug_deps, _ref2;
          if (err) {
            cb(err);
          }
          slug_deps = ((_ref2 = slug.recipe) != null ? _ref2.concat() : void 0) || [];
          for (group in recipe_deps) {
            deps = recipe_deps[group];
            if (group === module_name) {
              group_deps = deps.concat();
            }
          }
          slug_deps = slug_deps.concat(group_deps || []);
          return cb(CB_SUCCESS, slug_deps);
        });
      };
      harvest = function(cb, opts) {
        var args, js_path, mod_src, _ref2;
        if (opts == null) {
          opts = {};
        }
        _ref2 = get_paths(ctx), mod_src = _ref2.mod_src, js_path = _ref2.js_path;
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
    make_skelethon = function() {
      return require('./skelethon');
    };
    return {
      match: match,
      make_adaptor: make_adaptor,
      make_skelethon: make_skelethon
    };
  })();

}).call(this);
