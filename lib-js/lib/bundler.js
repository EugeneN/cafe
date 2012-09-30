// Generated by CoffeeScript 1.3.3
(function() {
  var BUILD_FILE_EXT, BUNDLE_HDR, BUNDLE_ITEM_FTR, BUNDLE_ITEM_HDR, CB_SUCCESS, EOL, FILE_ENCODING, RECIPE, SLUG_FN, VERSION, async, build_bundle, extend, flatten, fs, get_adaptors, get_mtime, is_dir, is_file, map, mkdirp, newest, path, read_json_file, reduce, resolve_deps, say, scream, shout, toposort, whisper, _ref, _ref1, _ref2, _ref3, _ref4,
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; },
    __slice = [].slice;

  fs = require('fs');

  path = require('path');

  async = require('async');

  mkdirp = require('mkdirp');

  _ref = require('functools'), map = _ref.map, reduce = _ref.reduce;

  get_adaptors = require('./adaptor');

  _ref1 = require('../lib/utils'), read_json_file = _ref1.read_json_file, extend = _ref1.extend;

  _ref2 = require('./utils'), flatten = _ref2.flatten, is_dir = _ref2.is_dir, is_file = _ref2.is_file, extend = _ref2.extend, newest = _ref2.newest, get_mtime = _ref2.get_mtime;

  _ref3 = (require('./logger'))("lib-bundle>"), say = _ref3.say, shout = _ref3.shout, scream = _ref3.scream, whisper = _ref3.whisper;

  _ref4 = require('../defs'), SLUG_FN = _ref4.SLUG_FN, FILE_ENCODING = _ref4.FILE_ENCODING, BUILD_FILE_EXT = _ref4.BUILD_FILE_EXT, RECIPE = _ref4.RECIPE, VERSION = _ref4.VERSION, EOL = _ref4.EOL, CB_SUCCESS = _ref4.CB_SUCCESS, BUNDLE_HDR = _ref4.BUNDLE_HDR, BUNDLE_ITEM_HDR = _ref4.BUNDLE_ITEM_HDR, BUNDLE_ITEM_FTR = _ref4.BUNDLE_ITEM_FTR;

  resolve_deps = function(_arg, resolve_deps_cb) {
    var adaptors, app_root, ctx, modules, process_module, recipe_deps;
    modules = _arg.modules, app_root = _arg.app_root, recipe_deps = _arg.recipe_deps, ctx = _arg.ctx;
    ' Resolves deps and assigns an adaptor to each module ';

    adaptors = get_adaptors();
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

  toposort = function(debug_info, modules) {
    var cur_module, dep, have_no_dependencies, m, modules_list, modules_without_deps, name, ordered_modules, pos, _i, _len;
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
      throw "Cyclic dependency found in " + debug_info.realm + "/" + debug_info.bundle.name;
    }
    return ordered_modules;
  };

  build_bundle = function(_arg) {
    var build_root, bundle_name, bundle_opts, cb, ctx, done, force_bundle, force_compile, get_target_fn, m, opts, realm, seq, seq2, seq2_harvester, seq_harvester, sorted_modules_list, write_bundle;
    realm = _arg.realm, bundle_name = _arg.bundle_name, bundle_opts = _arg.bundle_opts, force_compile = _arg.force_compile, force_bundle = _arg.force_bundle, sorted_modules_list = _arg.sorted_modules_list, build_root = _arg.build_root, ctx = _arg.ctx, cb = _arg.cb;
    get_target_fn = function() {
      return path.resolve(build_root, realm, bundle_name + BUILD_FILE_EXT);
    };
    write_bundle = function(file_list, cb) {
      var do_it, done, merge, read_file;
      read_file = function(fn, cb) {
        return fs.readFile(fn, FILE_ENCODING, function(err, data) {
          if (err) {
            return cb(CB_SUCCESS, [fn, "/* Can't read: " + err + " */"]);
          } else {
            return cb(CB_SUCCESS, [fn, data]);
          }
        });
      };
      merge = function(a, _arg1) {
        var fc, fn;
        fn = _arg1[0], fc = _arg1[1];
        return reduce((function(x, y) {
          return x + y;
        }), [a, BUNDLE_ITEM_HDR(fn), fc, BUNDLE_ITEM_FTR]);
      };
      done = function(err) {
        if (err) {
          ctx.fb.scream("Failed to write bundle " + realm + "/" + bundle_name + BUILD_FILE_EXT + ":\n" + err);
          return cb('target_error', err);
        } else {
          ctx.fb.say("Bundle " + realm + "/" + bundle_name + BUILD_FILE_EXT + " built.");
          return cb();
        }
      };
      do_it = function(err) {
        if (err) {
          return cb('fs_error', err);
        } else {
          return map.async(read_file, file_list, function(err, out) {
            return fs.writeFile(get_target_fn(), BUNDLE_HDR + (reduce(merge, [''].concat(out))), FILE_ENCODING, done);
          });
        }
      };
      return mkdirp(path.resolve(build_root, realm), do_it);
    };
    seq = (function() {
      var _i, _len, _results;
      _results = [];
      for (_i = 0, _len = sorted_modules_list.length; _i < _len; _i++) {
        m = sorted_modules_list[_i];
        _results.push(m.adaptor.harvest);
      }
      return _results;
    })();
    seq2 = (function() {
      var _i, _len, _results;
      _results = [];
      for (_i = 0, _len = sorted_modules_list.length; _i < _len; _i++) {
        m = sorted_modules_list[_i];
        _results.push(m.adaptor.last_modified);
      }
      return _results;
    })();
    opts = force_compile ? {
      full_args: {
        compile: {
          f: true
        }
      },
      own_args: {
        f: true
      }
    } : {};
    seq_harvester = function(adaptor_worker, cb) {
      return adaptor_worker(cb, opts);
    };
    seq2_harvester = function(adaptor_worker, cb) {
      return adaptor_worker(cb);
    };
    done = function(err, results) {
      var done_seq2, write_cb;
      if (err) {
        ctx.fb.scream("Level 2 build sequence error: " + err);
        return typeof cb === "function" ? cb('target_error', err) : void 0;
      } else {
        write_cb = function(not_changed) {
          return function(err, res) {
            if (err) {
              return cb(err, res);
            } else {
              return cb(CB_SUCCESS, [realm, bundle_name, not_changed]);
            }
          };
        };
        if (force_bundle) {
          return write_bundle(flatten(results), write_cb(false));
        } else {
          done_seq2 = function(err, result) {
            var max_src_mtime, recipe_mtime, target_mtime;
            if (err) {
              ctx.fb.scream("Error getting last_modified: " + err);
              return typeof cb === "function" ? cb('target_error', err) : void 0;
            } else {
              recipe_mtime = get_mtime(path.resolve(ctx.own_args.app_root, ctx.own_args.formula || RECIPE));
              max_src_mtime = newest(__slice.call(result).concat(__slice.call([recipe_mtime])));
              target_mtime = (function() {
                try {
                  return get_mtime(get_target_fn());
                } catch (e) {
                  return 0;
                }
              })();
              if (!(max_src_mtime < target_mtime)) {
                return write_bundle(flatten(results), write_cb(false));
              } else {
                ctx.fb.shout("Bundle " + realm + "/" + bundle_name + " still hot");
                return write_bundle(flatten(results), write_cb(true));
              }
            }
          };
          return async.map(seq2, seq2_harvester, done_seq2);
        }
      }
    };
    return async.map(seq, seq_harvester, done);
  };

  module.exports = {
    resolve_deps: resolve_deps,
    toposort: toposort,
    build_bundle: build_bundle
  };

}).call(this);
