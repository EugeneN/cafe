// Generated by CoffeeScript 1.4.0
(function() {
  var ADAPTORS_PATH, ADAPTOR_FN, JS_EXT, fs, is_dir, path, _ref,
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  path = require('path');

  fs = require('fs');

  is_dir = require('./utils').is_dir;

  _ref = require('../defs'), ADAPTORS_PATH = _ref.ADAPTORS_PATH, ADAPTOR_FN = _ref.ADAPTOR_FN, JS_EXT = _ref.JS_EXT;

  module.exports = function() {
    var fn_pattern;
    fn_pattern = "" + ADAPTOR_FN + JS_EXT;
    return (fs.readdirSync(ADAPTORS_PATH)).map(function(p) {
      return path.join(ADAPTORS_PATH, p);
    }).filter(function(fn) {
      return (is_dir(fn)) && __indexOf.call(fs.readdirSync(fn), fn_pattern) >= 0;
    }).map(function(d) {
      return require(path.join(d, fn_pattern));
    });
  };

}).call(this);
