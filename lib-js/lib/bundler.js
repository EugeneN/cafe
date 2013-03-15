// Generated by CoffeeScript 1.6.1
(function() {
  var BUILD_FILE_EXT, BUNDLE_HDR, BUNDLE_ITEM_FTR, BUNDLE_ITEM_HDR, CB_SUCCESS, EOL, EVENT_BUNDLE_CREATED, FILE_ENCODING, FILE_TYPE_COMMONJS, FILE_TYPE_PLAINJS, RECIPE, SLUG_FN, VERSION, async, build_bundle, exists, extend, flatten, fn_without_ext, fs, get_adaptors, get_modules_cache, get_mtime, is_array, is_dir, is_file, map, mkdirp, newest, or_, path, read_json_file, reduce, resolve_deps, say, scream, shout, toposort, whisper, wrap_bundle, wrap_modules, _ref, _ref1, _ref2, _ref3, _ref4, _ref5,
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  fs = require('fs');

  path = require('path');

  async = require('async');

  mkdirp = require('mkdirp');

  _ref = require('functools'), map = _ref.map, reduce = _ref.reduce;

  _ref1 = require('wrapper-commonjs'), wrap_bundle = _ref1.wrap_bundle, wrap_modules = _ref1.wrap_modules;

  get_modules_cache = require('./modules_cache').get_modules_cache;

  get_adaptors = require('./adaptor');

  _ref2 = require('../lib/utils'), read_json_file = _ref2.read_json_file, extend = _ref2.extend, exists = _ref2.exists, is_array = _ref2.is_array;

  _ref3 = require('./utils'), flatten = _ref3.flatten, is_dir = _ref3.is_dir, is_file = _ref3.is_file, extend = _ref3.extend, newest = _ref3.newest, get_mtime = _ref3.get_mtime, fn_without_ext = _ref3.fn_without_ext, or_ = _ref3.or_;

  _ref4 = (require('./logger'))("lib-bundle>"), say = _ref4.say, shout = _ref4.shout, scream = _ref4.scream, whisper = _ref4.whisper;

  _ref5 = require('../defs'), SLUG_FN = _ref5.SLUG_FN, FILE_ENCODING = _ref5.FILE_ENCODING, BUILD_FILE_EXT = _ref5.BUILD_FILE_EXT, RECIPE = _ref5.RECIPE, VERSION = _ref5.VERSION, EOL = _ref5.EOL, CB_SUCCESS = _ref5.CB_SUCCESS, BUNDLE_HDR = _ref5.BUNDLE_HDR, BUNDLE_ITEM_HDR = _ref5.BUNDLE_ITEM_HDR, BUNDLE_ITEM_FTR = _ref5.BUNDLE_ITEM_FTR, EVENT_BUNDLE_CREATED = _ref5.EVENT_BUNDLE_CREATED, FILE_TYPE_COMMONJS = _ref5.FILE_TYPE_COMMONJS, FILE_TYPE_PLAINJS = _ref5.FILE_TYPE_PLAINJS;

  resolve_deps = function(_arg, resolve_deps_cb) {
    var adaptors, app_root, ctx, modules, process_module, recipe_deps;
    modules = _arg.modules, app_root = _arg.app_root, recipe_deps = _arg.recipe_deps, ctx = _arg.ctx;
    ' Resolves deps and assigns an adaptor to each module ';
    adaptors = get_adaptors();
    if (!(adaptors.length > 0)) {
      throw 'No adaptors found for build';
    }
    app_root = path.resolve(ctx.own_args.app_root);
    process_module = function(module_name, process_module_cb) {
      var args, find_adaptor, new_ctx;
      args = {
        own_args: {
          mod_name: module_name
        }
      };
      new_ctx = extend(ctx, args);
      find_adaptor = function(adaptor_factory, find_adaptor_cb) {
        return adaptor_factory.match.async(new_ctx, function(err, match) {
          var adaptor;
          if (match) {
            adaptor = adaptor_factory.make_adaptor(new_ctx);
            return adaptor.get_deps(recipe_deps, function(err, module_deps) {
              var spec;
              if (err) {
                return find_adaptor_cb(err, void 0);
              } else {
                spec = {
                  name: module_name,
                  deps: module_deps,
                  adaptor: adaptor
                };
                return find_adaptor_cb(CB_SUCCESS, spec);
              }
            });
          } else {
            return find_adaptor_cb(err, void 0);
          }
        });
      };
      return async.map(adaptors, find_adaptor, function(err, found_modules_list) {
        var f;
        f = found_modules_list.filter(function(itm) {
          return itm !== void 0;
        });
        return process_module_cb(err, f[0]);
      });
    };
    if (modules) {
      return async.map(modules, process_module, function(err, found_modules_list) {
        var found_modules;
        found_modules = {};
        found_modules_list.map(function(mod_spec) {
          if (mod_spec !== void 0) {
            return found_modules[mod_spec.name] = mod_spec;
          }
        });
        return resolve_deps_cb(err, found_modules);
      });
    } else {
      return resolve_deps_cb(CB_SUCCESS, []);
    }
  };

  toposort = function(debug_info, modules, ctx) {
    var cur_module, dep, have_no_dependencies, k, m, message, modules_list, modules_names, modules_without_deps, name, ordered_modules, ordered_modules_names, pos, reduce_func, v, _i, _len;
    modules_list = (function() {
      var _results;
      _results = [];
      for (name in modules) {
        m = modules[name];
        _results.push(m);
      }
      return _results;
    })();
    have_no_dependencies = (function() {
      var _i, _len, _results;
      _results = [];
      for (_i = 0, _len = modules_list.length; _i < _len; _i++) {
        m = modules_list[_i];
        if (m.deps.length === 0) {
          _results.push(m);
        }
      }
      return _results;
    })();
    ordered_modules = [];
    while (have_no_dependencies.length > 0) {
      cur_module = have_no_dependencies.pop();
      ordered_modules.push(cur_module);
      modules_without_deps = have_no_dependencies.concat(ordered_modules);
      for (_i = 0, _len = modules_list.length; _i < _len; _i++) {
        m = modules_list[_i];
        if (!(!(__indexOf.call(modules_without_deps, m) >= 0))) {
          continue;
        }
        pos = m.deps.indexOf(cur_module.name);
        if ((pos != null) >= 0) {
          delete m.deps[pos];
          if (((function() {
            var _results;
            _results = [];
            for (dep in m.deps) {
              _results.push(dep);
            }
            return _results;
          })()).length === 0) {
            have_no_dependencies.push(m);
          }
        }
      }
    }
    if (ordered_modules.length !== modules_list.length) {
      modules_names = modules_list.map(function(i) {
        return i.name;
      });
      ordered_modules_names = ordered_modules.map(function(i) {
        return i.name;
      });
      if (modules_names.length > ordered_modules_names.length) {
        message = "Failed to load dependencies or cyclic imports" + ("[" + ((modules_names.filter(function(m) {
          return __indexOf.call(ordered_modules_names, m) < 0;
        })).join(',')) + "]");
        ctx.fb.scream(message);
      } else {
        reduce_func = function(a, b) {
          a[b] = !(b in a) ? 1 : a[b] + 1;
          return a;
        };
        ctx.fb.scream("Cyclic dependences found " + ((function() {
          var _ref6, _results;
          if (v > 1) {
            _ref6 = ordered_modules_names.reduce(reduce_func, {});
            _results = [];
            for (k in _ref6) {
              v = _ref6[k];
              _results.push(k);
            }
            return _results;
          }
        })()));
      }
      throw "Toposort failed " + debug_info.realm + "/" + debug_info.bundle.name + ":";
    }
    return ordered_modules;
  };

  build_bundle = function(_arg) {
    var build_bundle_cb, build_root, bundle_name, bundle_opts, cache_root, ctx, done, force_bundle, force_compile, get_bundle_mtime, get_target_fn, module_handler, module_precompile_handler, modules_cache, realm, recipe, sorted_modules_list, write_bundle;
    realm = _arg.realm, bundle_name = _arg.bundle_name, bundle_opts = _arg.bundle_opts, force_compile = _arg.force_compile, force_bundle = _arg.force_bundle, sorted_modules_list = _arg.sorted_modules_list, build_root = _arg.build_root, cache_root = _arg.cache_root, ctx = _arg.ctx, recipe = _arg.recipe, build_bundle_cb = _arg.build_bundle_cb;
    modules_cache = get_modules_cache(cache_root);
    get_target_fn = function() {
      return path.resolve(path.resolve(build_root, realm), bundle_name + BUILD_FILE_EXT);
    };
    write_bundle = function(results, cb) {
      var build_dir_path, do_it, done;
      results = results.filter(function(r) {
        return r != null;
      });
      done = function(err) {
        if (err) {
          ctx.fb.scream("Failed to write bundle " + realm + "/" + bundle_name + BUILD_FILE_EXT + ":\n" + err);
          return cb('target_error', err);
        } else {
          ctx.fb.say("Bundle " + realm + "/" + bundle_name + BUILD_FILE_EXT + " built.");
          return cb(CB_SUCCESS, [realm, bundle_name, false]);
        }
      };
      do_it = function(err) {
        var plain_js_files, res, s, _i, _j, _len, _len1, _ref6, _ref7;
        if (err) {
          return cb('fs_error', err);
        } else {
          if (!ctx.own_args.just_compile) {
            if (recipe.plainjs) {
              plain_js_files = recipe.plainjs.map(function(f) {
                return fn_without_ext(f);
              });
              for (_i = 0, _len = results.length; _i < _len; _i++) {
                res = results[_i];
                if (_ref6 = fn_without_ext(path.relative(ctx.own_args.app_root, res.mod_src)), __indexOf.call(plain_js_files, _ref6) >= 0) {
                  if (is_array(res.sources)) {
                    _ref7 = res.sources;
                    for (_j = 0, _len1 = _ref7.length; _j < _len1; _j++) {
                      s = _ref7[_j];
                      s.type = "plainjs";
                    }
                  } else {
                    res.sources.type = "plainjs";
                  }
                }
              }
            }
            return fs.writeFile(get_target_fn(), wrap_bundle(wrap_modules(results), BUNDLE_HDR), FILE_ENCODING, done);
          } else {
            ctx.fb.whisper("'just_compile -mode' is on, so no result bundle was written");
            ctx.emitter.emit(EVENT_BUNDLE_CREATED, results);
            return done(null);
          }
        }
      };
      if (!ctx.own_args.just_compile) {
        build_dir_path = path.resolve(build_root, realm);
        return mkdirp(build_dir_path, do_it);
      } else {
        return do_it(null);
      }
    };
    get_bundle_mtime = function() {
      return newest([
        ((function() {
          try {
            return get_mtime(get_target_fn());
          } catch (e) {
            return 0;
          }
        })()), get_mtime(path.resolve(ctx.own_args.app_root, ctx.own_args.formula || RECIPE))
      ]);
    };
    module_handler = function(module, cb) {
      return module.adaptor.last_modified(function(err, module_mtime) {
        if (or_(module_mtime > (modules_cache.get_cache_mtime(module)), ctx.own_args.f === true)) {
          return cb(CB_SUCCESS, [module, true]);
        } else {
          return cb(CB_SUCCESS, [module, false]);
        }
      });
    };
    module_precompile_handler = function(_arg1, cb) {
      var module, should_rebuild;
      module = _arg1[0], should_rebuild = _arg1[1];
      if (should_rebuild || module.adaptor.type === 'recipe') {
        ctx.fb.say("Harvesting module " + module.name);
        return module.adaptor.harvest(function(err, compiled_results) {
          if (!err) {
            modules_cache.save({
              module: module,
              source: compiled_results
            });
            return cb(CB_SUCCESS, compiled_results);
          } else {
            return cb('harvest_error');
          }
        });
      } else {
        return cb(CB_SUCCESS, (modules_cache.get(module.name)).source);
      }
    };
    done = function(err, raw_results) {
      "@raw_results : [[source, should_rebuild_bundle] ... ]";
      var get_harvested_results, should_rebuild_bundle;
      if (!raw_results.length) {
        ctx.fb.shout("Bundle " + realm + "/" + bundle_name + " is empty ...");
        build_bundle_cb(CB_SUCCESS, [realm, bundle_name, true]);
        return;
      }
      should_rebuild_bundle = raw_results.reduce((function(a, b) {
        return a || b[1];
      }), false);
      get_harvested_results = function(cb) {
        return async.map(raw_results, module_precompile_handler, function(err, results) {
          if (!err) {
            return cb(results);
          } else {
            return build_bundle_cb('bundle_error');
          }
        });
      };
      if (should_rebuild_bundle || force_compile) {
        return get_harvested_results(function(results) {
          return write_bundle(flatten(results), build_bundle_cb);
        });
      } else {
        if (!exists(get_target_fn())) {
          ctx.fb.shout("Missing bundle file " + realm + "/" + bundle_name + ", rebuilding from cache");
          return get_harvested_results(function(results) {
            return write_bundle(flatten(results), build_bundle_cb);
          });
        } else {
          ctx.fb.shout("Bundle " + realm + "/" + bundle_name + " is still hot, skip build");
          return build_bundle_cb(CB_SUCCESS, [realm, bundle_name, true]);
        }
      }
    };
    return async.map(sorted_modules_list, module_handler, done);
  };

  module.exports = {
    resolve_deps: resolve_deps,
    toposort: toposort,
    build_bundle: build_bundle
  };

}).call(this);
