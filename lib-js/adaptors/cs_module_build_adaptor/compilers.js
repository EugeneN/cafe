// Generated by CoffeeScript 1.3.3
(function() {
  var CoffeeScript, eco, fs;

  CoffeeScript = require('coffee-script');

  eco = require('eco');

  fs = require('fs');

  exports.coffee = {
    ext: 'coffee',
    compile: function(path) {
      return CoffeeScript.compile(fs.readFileSync(path, 'utf8'));
    }
  };

  exports.eco = {
    ext: 'eco',
    compile: function(path) {
      var content;
      if (eco.precompile) {
        content = eco.precompile(fs.readFileSync(path, 'utf8'));
        return "module.exports = " + content;
      } else {
        return eco.compile(fs.readFileSync(path, 'utf8'));
      }
    }
  };

}).call(this);
