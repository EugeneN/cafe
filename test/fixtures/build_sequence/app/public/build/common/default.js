
// Generated by CoffeeScript 1.4.0
(function() {
  "Simple common js bootstrapper.\nInspired by stitch.";

  var add, cache, diranme, doc, expand, modules, partial, pre, rem, require;

  if (!this.require) {
    modules = {};
    cache = {};
    if (!window.bootstrapper) {
      doc = window.document;
      add = doc.addEventListener ? 'addEventListener' : 'attachEvent';
      rem = doc.addEventListener ? 'removeEventListener' : 'detachEvent';
      pre = doc.addEventListener ? '' : 'on';
      window.bootstrapper = {
        init_queue: [],
        document_ready_queue: [],
        document_loaded_queue: [],
        modules: modules,
        run_queue: function(queue) {
          var f, _results;
          _results = [];
          while (f = queue.shift()) {
            _results.push(f());
          }
          return _results;
        },
        run_init_queue: function() {
          return window.bootstrapper.run_queue(window.bootstrapper.init_queue);
        }
      };
      if (doc.readyState === 'complete') {
        window.bootstrapper.run_queue(window.bootstrapper.document_ready_queue);
        window.bootstrapper.run_queue(window.bootstrapper.document_loaded_queue);
      } else {
        doc[add](pre + 'DOMContentLoaded', function() {
          return window.bootstrapper.run_queue(window.bootstrapper.document_ready_queue);
        });
        window[add](pre + 'load', function() {
          return window.bootstrapper.run_queue(window.bootstrapper.document_loaded_queue);
        });
      }
    }
    partial = function(fn) {
      var partial_args;
      partial_args = Array.prototype.slice.call(arguments);
      partial_args.shift();
      return function() {
        var a, arg, i, new_args, _i, _len, _ref;
        _ref = [[], 0], new_args = _ref[0], arg = _ref[1];
        for (i = _i = 0, _len = partial_args.length; _i < _len; i = ++_i) {
          a = partial_args[i];
          if (partial_args[i] === void 0) {
            new_args.push(arguments[arg++]);
          } else {
            new_args.push(partial_args[i]);
          }
        }
        return fn.apply(this, new_args);
      };
    };
    require = function(name, root, ns) {
      var fn, module, path;
      if (name === 'bootstrapper') {
        return window.bootstrapper;
      }
      path = expand(root, name);
      if ((ns != null) && !(modules[path] || modules[expand(path, './index')])) {
        path = "" + ns + "/" + (expand('', name));
      }
      module = cache[path];
      if (module) {
        return module.exports;
      } else if (fn = modules[path] || modules[path = expand(path, './index')]) {
        module = {
          id: path,
          exports: {}
        };
        try {
          cache[path] = module;
          fn(module.exports, module);
          return module.exports;
        } catch (e) {
          delete cache[path];
          throw e;
        }
      } else {
        throw "module '" + name + "' is not found";
      }
    };
    expand = function(root, name) {
      var i, part, parts, results, _i, _ref;
      results = [];
      if (/^\.\.?(\/|$)/.test(name)) {
        parts = [root, name].join('/').split('/');
      } else {
        parts = name.split('/');
      }
      for (i = _i = 0, _ref = parts.length - 1; 0 <= _ref ? _i <= _ref : _i >= _ref; i = 0 <= _ref ? ++_i : --_i) {
        part = parts[i];
        if (part === '..') {
          results.pop();
        } else if (part !== '.' && part !== '') {
          results.push(part);
        }
      }
      return results.join('/');
    };
    diranme = function(path) {
      return path.split('/').slice(0).join('/');
    };
    this.require = function(name) {
      return require(name, '');
    };
    this.require.define = function(ns, bundle) {
      var key, value, _key, _require;
      _require = partial(require, void 0, void 0, ns);
      for (key in bundle) {
        value = bundle[key];
        _key = ns ? "" + ns + "/" + key : key;
        modules[_key] = partial(value, void 0, _require, void 0);
        void 0;
      }
      return void 0;
    };
  }

}).call(this);


require.define('test1', {
/*ZB:  test1/index */
'index': function(exports, require, module) {(function() {
(function() {
  var monad1, monad2, monad3, test1;

  test1 = function() {
    return typeof console !== "undefined" && console !== null ? console.log("test1 initialized") : void 0;
  };

  monad1 = function() {};

  monad2 = function() {};

  monad3 = function() {};

  module.exports = test1();

}).call(this);

}).call(this);}
});