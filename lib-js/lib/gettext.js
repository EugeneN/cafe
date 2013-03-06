// Generated by CoffeeScript 1.4.0
(function() {
  var CONTEXT_GLUE, DEFAULT_DOMAIN, Gettext, fs, is_array, is_empty_object, is_valid_object, parse_po, parse_po_dequote, path, say, trim,
    __hasProp = {}.hasOwnProperty,
    __slice = [].slice;

  fs = require("fs");

  path = require("path");

  CONTEXT_GLUE = '\\004';

  DEFAULT_DOMAIN = 'messages';

  is_valid_object = function(o) {
    if (o === null) {
      return false;
    } else if (o === void 0) {
      return false;
    } else {
      return true;
    }
  };

  is_empty_object = function(o) {
    var i;
    return ((function() {
      var _results;
      _results = [];
      for (i in o) {
        if (!__hasProp.call(o, i)) continue;
        _results.push(i);
      }
      return _results;
    })()).length === 0;
  };

  parse_po_dequote = function(str) {
    var match;
    match = str.match(/^"(.*)"/);
    if (match) {
      str = match[1];
    }
    return str.replace(/\\"/g, "\"");
  };

  is_array = function(o) {
    return is_valid_object(o && o.constructor === Array);
  };

  trim = function(s) {
    return s.replace(/^\s*/, '').replace(/\s*$/, '');
  };

  say = function() {
    var a;
    a = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    return console.log.apply({}, a);
  };

  parse_po = function(data) {
    var buffer, cur, errors, hl, hlines, keylow, lastbuffer, line, lines, match, msg_ctxt_id, msgid_plural, pos, rv, str, trans, val, _i, _j, _len, _len1, _ref, _ref1, _ref2, _ref3;
    rv = {};
    buffer = {};
    lastbuffer = "";
    errors = [];
    lines = data.split("\n");
    for (_i = 0, _len = lines.length; _i < _len; _i++) {
      line = lines[_i];
      line = line.replace(/(\n|\r)+$/, '');
      if (/^$/.test(line)) {
        if (buffer.msgid) {
          msg_ctxt_id = ((_ref = buffer.msgctxt) != null ? _ref.length : void 0) ? buffer.msgctxt + CONTEXT_GLUE + buffer.msgid : buffer.msgid;
          msgid_plural = ((_ref1 = buffer.msgid_plural) != null ? _ref1.length : void 0) ? buffer.msgid_plural : null;
          trans = [];
          for (str in buffer) {
            match = str.match(/^msgstr_(\d+)/);
            if (match) {
              trans[parseInt(match[1], 10)] = buffer[str];
            }
          }
          trans.unshift(msgid_plural);
          if (trans.length > 1) {
            rv[msg_ctxt_id] = trans;
          }
          buffer = {};
          lastbuffer = "";
        }
      } else if (/^#/.test(line)) {

      } else if ((match = line.match(/^msgctxt\s+(.*)/))) {
        lastbuffer = 'msgctxt';
        buffer[lastbuffer] = parse_po_dequote(match[1]);
      } else if ((match = line.match(/^msgid\s+(.*)/))) {
        lastbuffer = 'msgid';
        buffer[lastbuffer] = parse_po_dequote(match[1]);
      } else if ((match = line.match(/^msgid_plural\s+(.*)/))) {
        lastbuffer = 'msgid_plural';
        buffer[lastbuffer] = parse_po_dequote(match[1]);
      } else if ((match = line.match(/^msgstr\s+(.*)/))) {
        lastbuffer = 'msgstr_0';
        buffer[lastbuffer] = parse_po_dequote(match[1]);
      } else if ((match = line.match(/^msgstr\[0\]\s+(.*)/))) {
        lastbuffer = 'msgstr_0';
        buffer[lastbuffer] = parse_po_dequote(match[1]);
      } else if ((match = line.match(/^msgstr\[(\d+)\]\s+(.*)/))) {
        lastbuffer = 'msgstr_' + match[1];
        buffer[lastbuffer] = parse_po_dequote(match[2]);
      } else if (/^"/.test(line)) {
        buffer[lastbuffer] += parse_po_dequote(line);
      } else {
        errors.push("Strange line [" + i + "] : " + line);
      }
    }
    if (buffer.msgid !== void 0) {
      msg_ctxt_id = ((_ref2 = buffer.msgctxt) != null ? _ref2.length : void 0) ? buffer.msgctxt + CONTEXT_GLUE + buffer.msgid : buffer.msgid;
      msgid_plural = ((_ref3 = buffer.msgid_plural) != null ? _ref3.length : void 0) ? buffer.msgid_plural : null;
      trans = [];
      for (str in buffer) {
        if ((match = str.match(/^msgstr_(\d+)/))) {
          trans[parseInt(match[1], 10)] = buffer[str];
        }
      }
      trans.unshift(msgid_plural);
      if (trans.length > 1) {
        rv[msg_ctxt_id] = trans;
      }
      buffer = {};
      lastbuffer = "";
    }
    if (rv[""] && rv[""][1]) {
      cur = {};
      hlines = rv[""][1].split(/\\n/);
      for (_j = 0, _len1 = hlines.length; _j < _len1; _j++) {
        hl = hlines[_j];
        pos = hl.indexOf(':', 0);
        if (pos !== -1) {
          keylow = hl.substring(0, pos).toLowerCase();
          val = hl.substring(pos + 1);
          if (cur[keylow] && cur[keylow].length) {
            errors.push("SKIPPING DUPLICATE HEADER LINE: " + hl);
          } else if (/#-#-#-#-#/.test(keylow)) {
            errors.push("SKIPPING ERROR MARKER IN HEADER: " + hl);
          } else {
            val = val.replace(/^\s+/, '');
            cur[keylow] = val;
          }
        } else {
          errors.push("PROBLEM LINE IN HEADER: " + hl);
          cur[hl] = '';
        }
      }
      rv[""] = cur;
    } else {
      rv[""] = {};
    }
    return rv;
  };

  Gettext = (function() {

    function Gettext(locale) {
      this.LOCALE = locale;
      this.LOCALE_DATA = {};
    }

    Gettext.prototype.parse_locale_data = function(locale_data, locale) {
      var L, data, domain, head, header, header_val, key, nplurals, plural_expr, val, _head, _parse_pf, _ref, _results, _x;
      L = this.LOCALE_DATA;
      if (!L[locale]) {
        L[locale] = {};
      }
      for (domain in locale_data) {
        if (!__hasProp.call(locale_data, domain)) continue;
        data = locale_data[domain];
        if (is_valid_object(data) && !is_empty_object(data)) {
          domain || (domain = DEFAULT_DOMAIN);
          if (!is_valid_object(L[locale][domain])) {
            L[locale][domain] = {};
          }
          if (!is_valid_object(L[locale][domain].head)) {
            L[locale][domain].head = {};
          }
          if (!is_valid_object(L[locale][domain].msgs)) {
            L[locale][domain].msgs = {};
          }
          for (key in data) {
            if (!__hasProp.call(data, key)) continue;
            val = data[key];
            if (key === '') {
              header = val;
              for (head in header) {
                if (!__hasProp.call(header, head)) continue;
                header_val = header[head];
                L[locale][domain].head[head.toLowerCase()] = header_val;
              }
            } else {
              L[locale][domain].msgs[key] = val;
            }
          }
        }
      }
      _results = [];
      for (domain in L[locale]) {
        _head = L[locale][domain].head;
        if (is_valid_object(_head['plural-forms']) && _head.plural_func === void 0) {
          _parse_pf = function(pf_str) {
            var a1, a2, i, nplurals, plural_expr, _, _ref, _ref1;
            _ref = (function() {
              var _i, _len, _ref, _results1;
              _ref = pf_str.split(';');
              _results1 = [];
              for (_i = 0, _len = _ref.length; _i < _len; _i++) {
                i = _ref[_i];
                _results1.push(trim(i));
              }
              return _results1;
            })(), a1 = _ref[0], a2 = _ref[1];
            _ref1 = (function() {
              var _i, _len, _ref1, _results1;
              _ref1 = a1.split('=');
              _results1 = [];
              for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
                i = _ref1[_i];
                _results1.push(trim(i));
              }
              return _results1;
            })(), _ = _ref1[0], nplurals = _ref1[1];
            plural_expr = (trim(a2)).replace(/\s*/g, '').replace(/plural=/, '');
            return [nplurals, plural_expr];
          };
          _ref = _parse_pf(_head['plural-forms']), nplurals = _ref[0], plural_expr = _ref[1];
          if (nplurals && plural_expr) {
            _x = function(nplurals, plural_expr) {
              return function(n) {
                return {
                  nplural: nplurals,
                  plural: eval(plural_expr)
                };
              };
            };
            _results.push(_head.plural_func = _x(nplurals, plural_expr));
          } else {
            throw "Syntax error in language file. " + ("Plural-Forms header is invalid ['" + plural_forms + "']");
          }
        } else if (_head.plural_func === void 0) {
          _results.push(_head.plural_func = function(n) {
            return {
              nplural: 2,
              plural: n !== 1 ? 1 : 0
            };
          });
        } else {
          _results.push(void 0);
        }
      }
      return _results;
    };

    Gettext.prototype.loadLanguageFile = function(file, callback) {
      var domain, locale,
        _this = this;
      if (!file) {
        return;
      }
      locale = this.LOCALE;
      if (!locale) {
        throw "Locale not set";
      }
      domain = path.basename(file, '.po');
      return fs.readFile(file, 'utf8', function(err, data) {
        var parsed, rv;
        if (err) {
          throw err;
        }
        parsed = parse_po(data);
        rv = {};
        if (parsed) {
          if (!parsed[""]) {
            parsed[""] = {};
          }
          if (!parsed[""].domain) {
            parsed[""].domain = domain;
          }
          domain = parsed[""].domain;
          rv[domain] = parsed;
          _this.parse_locale_data(rv, locale);
        }
        return typeof callback === "function" ? callback() : void 0;
      });
    };

    Gettext.prototype.loadLocaleDirectory = function(directory, callback) {
      var self;
      self = this;
      return fs.readdir(directory, function(err, files) {
        var pendingDirectories;
        pendingDirectories = files.length;
        if (!pendingDirectories) {
          return typeof callback === "function" ? callback() : void 0;
        }
        return files.forEach(function(file) {
          file = path.join(directory, file);
          return fs.stat(file, function(err, stats) {
            var l;
            if (!err && stats.isDirectory()) {
              l = file.match(/[^\/]+$/)[0];
              return fs.readdir(file, function(err, files) {
                var pendingFiles;
                pendingFiles = files.length;
                if (!pendingFiles) {
                  if (!!--pendingDirectories) {
                    return typeof callback === "function" ? callback() : void 0;
                  }
                }
                return files.forEach(function(file) {
                  file = path.join(directory, l, file);
                  if (path.extname(file) === '.po') {
                    return fs.stat(file, function(err, stats) {
                      if (!err && stats.isFile()) {
                        return self.loadLanguageFile(file, l, function() {
                          if (!--pendingFiles) {
                            if (!--pendingDirectories) {
                              return typeof callback === "function" ? callback() : void 0;
                            }
                          }
                        });
                      } else {
                        if (!--pendingFiles) {
                          if (!--pendingDirectories) {
                            return typeof callback === "function" ? callback() : void 0;
                          }
                        }
                      }
                    });
                  } else {
                    if (!--pendingFiles) {
                      if (!--pendingDirectories) {
                        return typeof callback === "function" ? callback() : void 0;
                      }
                    }
                  }
                });
              });
            } else {
              console.log(file);
              if (!--pendingDirectories) {
                return typeof callback === "function" ? callback() : void 0;
              }
            }
          });
        });
      });
    };

    Gettext.prototype.setlocale = function(category, locale) {
      category = 'LC_ALL';
      return this.LOCALE = locale;
    };

    Gettext.prototype.textdomain = function(d) {
      if (d != null ? d.length : void 0) {
        return d;
      } else {
        return void 0;
      }
    };

    Gettext.prototype.gettext = function(msgid) {
      return this.dcnpgettext(null, void 0, msgid, void 0, void 0, void 0);
    };

    Gettext.prototype.dgettext = function(domain, msgid) {
      return this.dcnpgettext(domain, void 0, msgid, void 0, void 0, void 0);
    };

    Gettext.prototype.dcgettext = function(domain, msgid, category) {
      return this.dcnpgettext(domain, void 0, msgid, void 0, void 0, category);
    };

    Gettext.prototype.ngettext = function(msgid, msgid_plural, n) {
      return this.dcnpgettext(null, void 0, msgid, msgid_plural, n, void 0);
    };

    Gettext.prototype.dngettext = function(domain, msgid, msgid_plural, n) {
      return this.dcnpgettext(domain, void 0, msgid, msgid_plural, n, void 0);
    };

    Gettext.prototype.dcngettext = function(domain, msgid, msgid_plural, n, category) {
      return this.dcnpgettext(domain, void 0, msgid, msgid_plural, n, category, category);
    };

    Gettext.prototype.pgettext = function(msgctxt, msgid) {
      return this.dcnpgettext(null, msgctxt, msgid, void 0, void 0, void 0);
    };

    Gettext.prototype.dpgettext = function(domain, msgctxt, msgid) {
      return this.dcnpgettext(domain, msgctxt, msgid, void 0, void 0, void 0);
    };

    Gettext.prototype.dcpgettext = function(domain, msgctxt, msgid, category) {
      return this.dcnpgettext(domain, msgctxt, msgid, void 0, void 0, category);
    };

    Gettext.prototype.npgettext = function(msgctxt, msgid, msgid_plural, n) {
      return this.dcnpgettext(null, msgctxt, msgid, msgid_plural, n, void 0);
    };

    Gettext.prototype.dnpgettext = function(domain, msgctxt, msgid, msgid_plural, n) {
      return this.dcnpgettext(domain, msgctxt, msgid, msgid_plural, n, void 0);
    };

    Gettext.prototype.dcnpgettext = function(domain, msgctxt, msgid, msgid_plural, n, category) {
      var category_name, dom, domain_used, domainname, found, locale_data, msg_ctxt_id, p, plural, rv, trans, translation, val, x, _i, _len, _locale_, _ref, _ref1;
      if (!is_valid_object(msgid)) {
        return '';
      }
      plural = is_valid_object(msgid_plural);
      msg_ctxt_id = is_valid_object(msgctxt) ? msgctxt + CONTEXT_GLUE + msgid : msgid;
      domainname = is_valid_object(domain) ? domain : DEFAULT_DOMAIN;
      category_name = 'LC_MESSAGES';
      category = 5;
      locale_data = [];
      if (is_valid_object((_ref = this.LOCALE_DATA[this.LOCALE]) != null ? _ref[domainname] : void 0)) {
        locale_data.push(this.LOCALE_DATA[this.LOCALE][domainname]);
      } else if (this.LOCALE_DATA[this.LOCALE] !== void 0) {
        _ref1 = this.LOCALE_DATA[this.LOCALE];
        for (dom in _ref1) {
          if (!__hasProp.call(_ref1, dom)) continue;
          val = _ref1[dom];
          locale_data.push(val);
        }
      }
      trans = [];
      found = false;
      domain_used;

      if (locale_data.length) {
        for (_i = 0, _len = locale_data.length; _i < _len; _i++) {
          _locale_ = locale_data[_i];
          if (is_valid_object(_locale_.msgs[msg_ctxt_id])) {
            trans = (function() {
              var _j, _len1, _ref2, _results;
              _ref2 = _locale_.msgs[msg_ctxt_id];
              _results = [];
              for (_j = 0, _len1 = _ref2.length; _j < _len1; _j++) {
                x = _ref2[_j];
                _results.push(x);
              }
              return _results;
            })();
            trans.shift();
            domain_used = _locale_;
            found = true;
            if (trans.length > 0 && trans[0].length !== 0) {
              break;
            }
          }
        }
      }
      if (trans.length === 0 || trans[0].length === 0) {
        trans = [msgid, msgid_plural];
      }
      translation = trans[0];
      if (plural) {
        p = found && is_valid_object(domain_used.head.plural_func) ? (rv = domain_used.head.plural_func(n), !rv.plural ? rv.plural = 0 : void 0, !rv.nplural ? rv.nplural = 0 : void 0, rv.nplural <= rv.plural ? rv.plural = 0 : void 0, rv.plural) : n !== 1 ? 1 : 0;
        if (is_valid_object(trans[p])) {
          translation = trans[p];
        }
      }
      return translation;
    };

    Gettext.prototype.strargs = function(str, args) {
      var arg_n, i, length_n, match_n, newstr, _ref;
      if (args === null || args === (void 0)) {
        args = [];
      } else if (args.constructor !== Array) {
        args = [args];
      }
      newstr = "";
      while (true) {
        i = str.indexOf('%');
        if (i === -1) {
          newstr += str;
          break;
        }
        newstr += str.substr(0, i);
        if (str.substr(i, 2) === '%%') {
          newstr += '%';
          str = str.substr(i + 2);
        } else if (match_n = str.substr(i).match(/^%(\d+)/)) {
          arg_n = parseInt(match_n[1], 10);
          length_n = match_n[1].length;
          if (arg_n > 0 && ((_ref = args[arg_n - 1]) !== null && _ref !== (void 0))) {
            newstr += args[arg_n - 1];
          }
          str = str.substr(i + 1 + length_n);
        } else {
          newstr += '%';
          str = str.substr(i + 1);
        }
      }
      return newstr;
    };

    return Gettext;

  })();

  module.exports = Gettext;

}).call(this);
