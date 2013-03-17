// Generated by CoffeeScript 1.6.1
(function() {
  var Minifier, events, exists, fs, help, is_dir, is_file, make_target, minify, path, say, scream, shout, whisper, _ref, _ref1;

  help = ["Minifies javascript files.\n\nParameters:\n    --src            - source dir with js files. This dir is walked\n                       recursively.\n\n    --dst            - destination dir for placing minified files into.\n                       Minified files will be put to the base dir of each\n                       respective source file should this parameter\n                       be omitted.\n\n    --pattern=<...>  - file pattern for minification\n                       if this argument is specified then the --src parameter\n                       is skipped\n\n    -f               - forces minification even if the source file hasn't changed"];

  fs = require('fs');

  path = require('path');

  events = require('events');

  Minifier = require('../lib/minifier');

  _ref = require('../lib/utils'), is_dir = _ref.is_dir, is_file = _ref.is_file, exists = _ref.exists;

  make_target = require('../lib/target').make_target;

  _ref1 = (require('../lib/logger'))('Minify>'), say = _ref1.say, shout = _ref1.shout, scream = _ref1.scream, whisper = _ref1.whisper;

  minify = function(ctx, cb) {
    var minifier;
    if (!exists(ctx.own_args.src)) {
      ctx.fb.shout("Wrong 'src' parameter for minify: '" + ctx.own_args.src + "'");
      ctx.print_help();
    }
    if ((ctx.own_args.dst != null) && !(is_dir(ctx.own_args.dst))) {
      ctx.fb.shout("Wrong 'dst' parameter for minify: '" + ctx.own_args.dst + "'");
      ctx.print_help();
    }
    minifier = new Minifier(ctx);
    return minifier.minify(cb, ctx.own_args.f);
  };

  module.exports = make_target("minify", minify, help);

}).call(this);