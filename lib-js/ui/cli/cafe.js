// Generated by CoffeeScript 1.3.3
(function() {
  var EVENT_CAFE_DONE, EXIT_HELP, EXIT_OTHER_ERROR, EXIT_SIGINT, EXIT_SUCCESS, FAILURE_ICO, LOG_PREFIX, PR_SET_PDEATHSIG, SIGINT, SIGTERM, START_TIME, SUCCESS_ICO, apply1, apply2, cafe_factory, draw_logo, events, exit_cb, fb, green, growl, is_array, logger, murmur, path, pessimist, red, say, scream, shout, subscribe, whisper, yellow, _base, _ref,
    __slice = [].slice,
    _this = this;

  (_base = Function.prototype).partial || (_base.partial = function() {
    var f, part_args;
    part_args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    f = this;
    return function() {
      var args;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      return f.apply(this, __slice.call(part_args).concat(__slice.call(args)));
    };
  });

  LOG_PREFIX = 'UI/CLI>';

  path = require('path');

  events = require('events');

  growl = require('growl');

  cafe_factory = require('../../cafe');

  pessimist = require('../../lib/pessimist');

  is_array = require('../../lib/utils').is_array;

  draw_logo = require('../../lib/pictures').draw_logo;

  logger = (require('../../lib/logger'))(LOG_PREFIX);

  _ref = require('../../defs'), EXIT_HELP = _ref.EXIT_HELP, PR_SET_PDEATHSIG = _ref.PR_SET_PDEATHSIG, EXIT_SIGINT = _ref.EXIT_SIGINT, EXIT_SIGINT = _ref.EXIT_SIGINT, SIGTERM = _ref.SIGTERM, SIGINT = _ref.SIGINT, EXIT_OTHER_ERROR = _ref.EXIT_OTHER_ERROR, EVENT_CAFE_DONE = _ref.EVENT_CAFE_DONE, EXIT_SUCCESS = _ref.EXIT_SUCCESS, SUCCESS_ICO = _ref.SUCCESS_ICO, FAILURE_ICO = _ref.FAILURE_ICO;

  green = logger.green, yellow = logger.yellow, red = logger.red;

  apply1 = function(type, color) {
    return function() {
      var a;
      a = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      return console[type].apply(console, [color(LOG_PREFIX)].concat(a));
    };
  };

  say = apply1('log', green);

  shout = apply1('info', yellow);

  scream = apply1('error', red);

  whisper = apply1('error', red);

  murmur = function() {
    var a;
    a = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    return console.log.apply(console, a);
  };

  apply2 = function(type, color) {
    return function(a) {
      var msg, prefix;
      prefix = color ? [color(LOG_PREFIX)] : [];
      msg = prefix.concat((is_array(a) ? a : [a]));
      return console[type].apply(console, msg);
    };
  };

  fb = {
    say: apply2('log', green),
    shout: apply2('info', yellow),
    scream: apply2('error', red),
    whisper: apply2('error', red),
    murmur: apply2('log')
  };

  START_TIME = new Date;

  process.on('SIGINT', function() {
    say("SIGINT encountered, Cafe's closing");
    return exit_cb(EXIT_SIGINT);
  });

  process.on('SIGTERM', function() {
    say("SIGTERM encountered, Cafe's closing");
    return exit_cb(EXIT_SIGTERM);
  });

  exit_cb = function(status_code) {
    fb.say("Cafe was open " + ((new Date - START_TIME) / 1000) + "s");
    return process.exit(status_code);
  };

  subscribe = function(emitter) {
    return emitter.on(EVENT_CAFE_DONE, function(status, error) {
      switch (status) {
        case EXIT_OTHER_ERROR:
          growl("Cafe error <" + error + ">", {
            image: FAILURE_ICO
          });
          return console.log(path.resolve(FAILURE_ICO));
        case EXIT_SUCCESS:
          growl("Cafe success :)", {
            image: SUCCESS_ICO
          });
          return console.log(path.resolve(SUCCESS_ICO));
      }
    });
  };

  module.exports = function() {
    var argv, emitter, go, is_growl, ready;
    argv = pessimist(process.argv);
    if (argv.global.hasOwnProperty('nocolor')) {
      logger.nocolor(true);
    }
    if (argv.global.hasOwnProperty('shutup')) {
      logger.shutup(true);
    }
    if (argv.global.hasOwnProperty('debug')) {
      logger.panic_mode(true);
    }
    is_growl = !argv.global.hasOwnProperty('nogrowl');
    if (!argv.global.hasOwnProperty('nologo')) {
      draw_logo(fb);
    }
    emitter = new events.EventEmitter;
    if (is_growl) {
      subscribe(emitter);
    }
    ready = cafe_factory(emitter).ready;
    go = ready({
      exit_cb: exit_cb,
      fb: fb
    }).go;
    return go({
      args: argv
    });
  };

}).call(this);
