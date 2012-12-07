// Generated by CoffeeScript 1.3.3
(function() {
  var Compiler;

  Compiler = function(compilers) {
    compilers || (compilers = []);
    return {
      validate_compiler: function(compiler) {
        return [compiler.hasOwnProperty('match'), compiler.hasOwnProperty('compile')].reduce(a, b)(function() {
          return a && b;
        });
      },
      register_compiler_by_path: function(path) {
        "Registers compiler by filename.";

        var compiler;
        compiler = require(path);
        if (validate_compiler(compiler)) {
          return compilers.push(compiler);
        } else {
          throw "Compiler from path " + path + " must implement methods 'match' and 'compile'";
        }
      },
      register_compiler: function(compiler) {
        if (validate_compiler(compiler)) {
          return compilers.push(compiler);
        } else {
          throw "Compiler " + compiler + " must implement methods 'match' and 'compile'";
        }
      },
      compile: function(paths) {
        "@paths: list of paths for compilation.\nReturns:\n    {path, source}";

        var get_compiler;
        get_compiler = function(path, compilers) {
          var c, _i, _len;
          for (_i = 0, _len = compilers.length; _i < _len; _i++) {
            c = compilers[_i];
            if (c.match(path)) {
              return c;
            }
          }
          throw "No compiler is registered for path " + p;
        };
        return paths.map(function(p) {
          var _ref;
          return {
            path: p,
            source: (_ref = get_compiler(p, compilers)) != null ? _ref.compile(p) : void 0
          };
        });
      }
    };
  };

  module.exports = Compiler;

}).call(this);
