

(function(/*! Stitch !*/) {
  if (!this.require) {
    var modules = {}, cache = {}, require = function(name, root) {
      var path = expand(root, name), indexPath = expand(path, './index'), module, fn;
      module   = cache[path] || cache[indexPath]      
      if (module) {
        return module;
      } else if (fn = modules[path] || modules[path = indexPath]) {
        module = {id: path, exports: {}};
        cache[path] = module.exports;
        fn(module.exports, function(name) {
          return require(name, dirname(path));
        }, module);
        return cache[path] = module.exports;
      } else {
        throw 'module ' + name + ' not found';
      }
    }, expand = function(root, name) {
      var results = [], parts, part;
      if (/^\.\.?(\/|$)/.test(name)) {
        parts = [root, name].join('/').split('/');
      } else {
        parts = name.split('/');
      }
      for (var i = 0, length = parts.length; i < length; i++) {
        part = parts[i];
        if (part == '..') {
          results.pop();
        } else if (part != '.' && part != '') {
          results.push(part);
        }
      }
      return results.join('/');
    }, dirname = function(path) {
      return path.split('/').slice(0, -1).join('/');
    };
    this.require = function(name) {
      return require(name, '');
    }
    this.require.define = function(bundle) {
      for (var key in bundle)
        modules[key] = bundle[key];
    };
    this.require.modules = modules;
    this.require.cache   = cache;
  }
  return this.require.define;
}).call(this)({
  "lib/setup": function(exports, require, module) {(function() {

  require('spine');

  require('spine/lib/local');

  require('spine/lib/ajax');

  require('spine/lib/manager');

  require('spine/lib/route');

  require('spine/lib/tmpl');

}).call(this);
}, "PAutocomplete": function(exports, require, module) {(function() {
  var $, DEFAULT_DELAY, DEFAULT_ITEMS_SELECTOR, DEFAULT_MIN_CHARS, EVENT_DROPDOWN_ITEM_HIGHLIGHT, EVENT_DROPDOWN_ITEM_SELECT, EVENT_DROPDOWN_POPUP_SHOW, EVENT_INPUT_ITEM_SELECT, EVENT_ITEM_SELECTED, EVENT_LETTER_ENTERED, EVENT_REQUEST_SUGGESTIONS, PAutocompleteController, PAutocompleteDropdownController, PAutocompleteInputController, Spine, _ref, _ref1,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  Spine = require('spine');

  $ = Spine.$;

  _ref = require('controllers/PAutocompleteDropdownController'), PAutocompleteDropdownController = _ref[0], EVENT_DROPDOWN_ITEM_SELECT = _ref[1], EVENT_DROPDOWN_ITEM_HIGHLIGHT = _ref[2], EVENT_DROPDOWN_POPUP_SHOW = _ref[3];

  _ref1 = require('controllers/PAutocompleteInputController'), PAutocompleteInputController = _ref1[0], EVENT_INPUT_ITEM_SELECT = _ref1[1], EVENT_REQUEST_SUGGESTIONS = _ref1[2], EVENT_LETTER_ENTERED = _ref1[3];

  DEFAULT_DELAY = 300;

  DEFAULT_MIN_CHARS = 3;

  DEFAULT_ITEMS_SELECTOR = '.item';

  EVENT_ITEM_SELECTED = 'PA.item_selected';

  PAutocompleteController = (function(_super) {

    __extends(PAutocompleteController, _super);

    function PAutocompleteController(options) {
      this.process_suggest = __bind(this.process_suggest, this);

      var _this = this;
      PAutocompleteController.__super__.constructor.apply(this, arguments);
      if (!('input_selector' in options)) {
        throw 'input_selector param is missing';
      }
      if (!('url' in options)) {
        throw 'url param is missing';
      }
      if (!('template' in options)) {
        throw 'template param is missing';
      }
      if (!('popup_selector' in options)) {
        throw 'poup_selector param is missing';
      }
      if (!('delay' in options)) {
        options.delay = DEFAULT_DELAY;
      }
      if (!('min_input_chars' in options)) {
        options.min_input_chars = DEFAULT_MIN_CHARS;
      }
      if (!('items_selector' in options)) {
        options.items_selector = DEFAULT_ITEMS_SELECTOR;
      }
      if (options.selected_item_handler) {
        this.selected = options.selected_item_handler;
      }
      this.build_suggest_params_handler = options.build_suggest_params_handler || this._get_default_suggest_params;
      if ('form_id' in options) {
        this.form_id = options.form_id;
      }
      this.suggest_url = options.url;
      this._dropdown = new PAutocompleteDropdownController({
        active_item_class: options.active_item_class,
        popup_selector: options.popup_selector,
        input_selector: options.input_selector,
        item_list_selector: options.items_selector,
        template: options.template
      });
      this._input = new PAutocompleteInputController({
        el: $(options.input_selector),
        suggest_url: options.url,
        dropdown: this._dropdown,
        min_input_chars: options.min_input_chars,
        delay: options.delay
      });
      this._input.bind(EVENT_REQUEST_SUGGESTIONS, this.process_suggest);
      this._input.bind(EVENT_INPUT_ITEM_SELECT, function(item) {
        return _this.trigger(EVENT_ITEM_SELECTED, item);
      });
      this._dropdown.bind(EVENT_DROPDOWN_ITEM_HIGHLIGHT, function(item) {
        return _this._input.el.val(item);
      });
      this._dropdown.bind(EVENT_DROPDOWN_ITEM_SELECT, function(item) {
        return _this.trigger(EVENT_ITEM_SELECTED, item);
      });
      if (this.selected) {
        this.bind(EVENT_ITEM_SELECTED, this.selected);
      }
      this.process_highlight();
    }

    PAutocompleteController.prototype.on_item_selected = function(handler) {
      return this.bind(EVENT_ITEM_SELECTED, handler);
    };

    PAutocompleteController.prototype.process_suggest = function() {
      var _this = this;
      if (this.xhr) {
        this.xhr.abort();
      }
      return this.xhr = $.ajax({
        url: this.suggest_url,
        data: this.build_suggest_params_handler(),
        success: function(data) {
          return _this._input.process_suggest_items(data);
        },
        error: function(xhr, textStatus, err) {
          return _this.log({
            textStatus: textStatus,
            error: err
          });
        }
      });
    };

    PAutocompleteController.prototype.process_highlight = function() {
      var make_match_bold,
        _this = this;
      make_match_bold = function() {
        var item, j_item, match, patt, _i, _len, _ref2, _results;
        if (_this._input.el.val() === "") {
          return;
        }
        patt = new RegExp(_this._input.el.val(), "ig");
        _ref2 = _this._dropdown.items_list();
        _results = [];
        for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
          item = _ref2[_i];
          j_item = $(item);
          match = j_item.text().match(patt);
          _results.push(j_item.html(j_item.text().replace(patt, "<strong>" + match + "</strong>")));
        }
        return _results;
      };
      this._dropdown.bind(EVENT_DROPDOWN_POPUP_SHOW, make_match_bold);
      return this._input.bind(EVENT_LETTER_ENTERED, make_match_bold);
    };

    PAutocompleteController.prototype._get_default_suggest_params = function() {
      return {
        'term': this._input.el.val()
      };
    };

    return PAutocompleteController;

  })(Spine.Controller);

  module.exports = PAutocompleteController;

}).call(this);
}, "controllers/PAutocompleteDropdownController": function(exports, require, module) {(function() {
  var $, DEFAULT_ACTIVE_CLASS, EVENT_DROPDOWN_ITEM_DEACTIVATE, EVENT_DROPDOWN_ITEM_HIGHLIGHT, EVENT_DROPDOWN_ITEM_SELECT, EVENT_DROPDOWN_POPUP_SHOW, PAutocompleteDropdownController, Spine,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  Spine = require('spine');

  $ = Spine.$;

  EVENT_DROPDOWN_ITEM_SELECT = 'dropdown_item_select';

  EVENT_DROPDOWN_ITEM_HIGHLIGHT = 'dropdown_item_highlight';

  EVENT_DROPDOWN_ITEM_DEACTIVATE = 'dropdown_item_deactivate';

  EVENT_DROPDOWN_POPUP_SHOW = 'dropdown_popup_show';

  DEFAULT_ACTIVE_CLASS = 'active';

  PAutocompleteDropdownController = (function(_super) {

    __extends(PAutocompleteDropdownController, _super);

    function PAutocompleteDropdownController() {
      this.item_down = __bind(this.item_down, this);

      this.item_up = __bind(this.item_up, this);

      this.hide_popup = __bind(this.hide_popup, this);

      this.show_popup = __bind(this.show_popup, this);

      this._init_position = __bind(this._init_position, this);

      this.render = __bind(this.render, this);

      var close_if_click_outside_popup,
        _this = this;
      PAutocompleteDropdownController.__super__.constructor.apply(this, arguments);
      this.logPrefix = '(PAutocompleteController)';
      if (!this.popup_selector) {
        throw "popup_selector param is missing";
      }
      if (!this.active_item_class) {
        this.active_item_class = DEFAULT_ACTIVE_CLASS;
      }
      this.selected_index = 0;
      $('body').append(this.render());
      this.dropdown_active = false;
      close_if_click_outside_popup = function(e) {
        if ($(e.target).parents(_this.popup_selector).length === 0 && '#' + $(e.target).attr('id') !== _this.input_selector) {
          _this.hide_popup();
        }
        return true;
      };
      $(document).click(close_if_click_outside_popup);
      this.el.click(function(ev) {
        var item;
        if (_this._check_if_item_from_target(ev)) {
          item = _this._get_crossbrowser_event_target(ev);
          _this.selected_index = $(_this.item_list_selector).index(item);
          _this.highlight_item(_this.selected_index);
          return _this.trigger(EVENT_DROPDOWN_ITEM_SELECT, item.data());
        }
      });
    }

    PAutocompleteDropdownController.prototype.get_selected_item = function() {
      if (this.dropdown_active) {
        return $(this.items_list()[this.selected_index]).data();
      } else {
        return null;
      }
    };

    PAutocompleteDropdownController.prototype.render = function() {
      return this.html(require(this.template));
    };

    PAutocompleteDropdownController.prototype._init_position = function() {
      /* Method for calculating popup windown offset and width
      */

      var input_selector, left, top;
      input_selector = $(this.input_selector);
      top = input_selector.offset().top + input_selector.outerHeight();
      left = input_selector.offset().left;
      $(this.popup_selector).outerWidth(input_selector.outerWidth());
      return $(this.popup_selector).css({
        top: top,
        left: left
      });
    };

    PAutocompleteDropdownController.prototype._check_if_item_from_target = function(ev) {
      var classes, i, id, item, _ref;
      item = this._get_crossbrowser_event_target(ev);
      classes = (function() {
        var _i, _len, _ref, _results;
        _ref = item.attr('class').split(' ');
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          i = _ref[_i];
          _results.push("." + i);
        }
        return _results;
      })();
      id = "#" + (item.attr('id'));
      return _ref = this.item_list_selector, __indexOf.call(classes, _ref) >= 0;
    };

    PAutocompleteDropdownController.prototype._get_crossbrowser_event_target = function(ev) {
      var target;
      target = ev.target;
      if (!target) {
        target = ev.srcElement;
      }
      return $(target);
    };

    PAutocompleteDropdownController.prototype.show_popup = function(items) {
      var hover_in, hover_out,
        _this = this;
      this.html(require(this.template)({
        items: items
      }));
      this._init_position();
      hover_in = function(ev) {
        var item;
        item = _this._get_crossbrowser_event_target(ev);
        return item.addClass(_this.active_item_class);
      };
      hover_out = function(ev) {
        var item;
        item = _this._get_crossbrowser_event_target(ev);
        return item.removeClass(_this.active_item_class);
      };
      this.el.find(this.item_list_selector).hover(hover_in, hover_out);
      $(this.el).show();
      return this.trigger(EVENT_DROPDOWN_POPUP_SHOW);
    };

    PAutocompleteDropdownController.prototype.hide_popup = function() {
      this.selected_index = 0;
      $(this.el).hide();
      return this.dropdown_active = false;
    };

    PAutocompleteDropdownController.prototype.items_list = function() {
      return this.el.find(this.item_list_selector);
    };

    PAutocompleteDropdownController.prototype.item_up = function() {
      if (this.dropdown_active && this.selected_index === 0) {
        this.dropdown_deactivate();
        return;
      }
      if (!this.dropdown_active && this.selected_index === 0) {
        this.dropdown_activate(false);
        return;
      }
      this.selected_index -= 1;
      return this.highlight_item(this.selected_index);
    };

    PAutocompleteDropdownController.prototype.item_down = function() {
      if (!this.dropdown_active && this.selected_index === 0) {
        this.dropdown_activate();
        return;
      }
      if (this.dropdown_active && this.selected_index === this.items_list().length - 1) {
        this.dropdown_deactivate();
        return;
      }
      this.selected_index += 1;
      return this.highlight_item(this.selected_index);
    };

    PAutocompleteDropdownController.prototype.highlight_item = function(index) {
      this.items_list().removeClass(this.active_item_class);
      $(this.items_list()[index]).addClass(this.active_item_class);
      return this.trigger(EVENT_DROPDOWN_ITEM_HIGHLIGHT, $.trim($(this.items_list()[index]).text()));
    };

    PAutocompleteDropdownController.prototype.dropdown_activate = function(top_active) {
      if (top_active == null) {
        top_active = true;
      }
      if (top_active) {
        this.selected_index = 0;
      } else {
        this.selected_index = this.items_list().length - 1;
      }
      this.dropdown_active = true;
      return this.highlight_item(this.selected_index);
    };

    PAutocompleteDropdownController.prototype.dropdown_deactivate = function() {
      this.items_list().removeClass(this.active_item_class);
      this.dropdown_active = false;
      this.trigger('dropdown_deactivate');
      return this.selected_index = 0;
    };

    return PAutocompleteDropdownController;

  })(Spine.Controller);

  module.exports = [PAutocompleteDropdownController, EVENT_DROPDOWN_ITEM_SELECT, EVENT_DROPDOWN_ITEM_HIGHLIGHT, EVENT_DROPDOWN_POPUP_SHOW];

}).call(this);
}, "controllers/PAutocompleteInputController": function(exports, require, module) {(function() {
  var $, EVENT_INPUT_ITEM_SELECT, EVENT_LETTER_ENTERED, EVENT_REQUEST_SUGGESTIONS, PAutocompleteInputController, Spine, keyCode,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  Spine = require('spine');

  $ = Spine.$;

  keyCode = $.ui.keyCode;

  EVENT_INPUT_ITEM_SELECT = 'input_item_selected';

  EVENT_REQUEST_SUGGESTIONS = 'input_request_suggestions';

  EVENT_LETTER_ENTERED = 'input_letter_entered';

  PAutocompleteInputController = (function(_super) {

    __extends(PAutocompleteInputController, _super);

    function PAutocompleteInputController() {
      this._show_popup = __bind(this._show_popup, this);

      this._hide_popup = __bind(this._hide_popup, this);

      this._event_keyup = __bind(this._event_keyup, this);

      this._event_keydown = __bind(this._event_keydown, this);

      this.process_suggest_items = __bind(this.process_suggest_items, this);

      /*
              Accepts:
              @el: main element.
              @dropdown: Object for displaying recieved items.
      */

      var _this = this;
      PAutocompleteInputController.__super__.constructor.apply(this, arguments);
      this.dropdown.bind('dropdown_deactivate', function() {
        return _this.el.val(_this._last_value);
      });
      this._popup_active = false;
      this._last_value = '';
      $(this.el).keyup(this._event_keyup);
      $(this.el).keydown(this._event_keydown);
    }

    PAutocompleteInputController.prototype.process_suggest_items = function(items) {
      if (items.length > 0) {
        return this._show_popup(items);
      } else {
        return this._hide_popup();
      }
    };

    PAutocompleteInputController.prototype._event_keydown = function(ev) {
      switch (ev.keyCode) {
        case keyCode.UP:
          event.preventDefault();
          this.dropdown.item_up();
          break;
        case keyCode.DOWN:
          this.dropdown.item_down();
          break;
        case keyCode.ENTER:
          event.preventDefault();
      }
      return void 0;
    };

    PAutocompleteInputController.prototype._event_keyup = function(ev) {
      var timeout_func,
        _this = this;
      if (!this._control_buttons_handle(ev)) {
        this.trigger(EVENT_LETTER_ENTERED);
        if (this.el.val().length + 1 <= this.min_input_chars) {
          this._hide_popup();
        } else {
          this._last_value = this.el.val();
          timeout_func = function() {
            return _this.trigger(EVENT_REQUEST_SUGGESTIONS, _this.el.val());
          };
          if (this._timeout_handler) {
            clearTimeout(this._timeout_handler);
          }
          this._timeout_handler = setTimeout(timeout_func, this.delay);
        }
      }
      return void 0;
    };

    PAutocompleteInputController.prototype._control_buttons_handle = function(event) {
      switch (event.keyCode) {
        case keyCode.UP:
          break;
        case keyCode.DOWN:
          break;
        case keyCode.ESCAPE:
          this.el.val(this._last_value);
          this._hide_popup();
          break;
        case keyCode.ENTER:
          event.preventDefault();
          this.trigger(EVENT_INPUT_ITEM_SELECT, this.dropdown.get_selected_item());
          break;
        default:
          return false;
      }
      return true;
    };

    PAutocompleteInputController.prototype._hide_popup = function() {
      if (this._popup_active) {
        this.dropdown.hide_popup();
        return this._popup_active = false;
      }
    };

    PAutocompleteInputController.prototype._show_popup = function(items) {
      if (!this._popup_active) {
        this._popup_active = true;
      }
      return this.dropdown.show_popup(items);
    };

    return PAutocompleteInputController;

  })(Spine.Controller);

  module.exports = [PAutocompleteInputController, EVENT_INPUT_ITEM_SELECT, EVENT_REQUEST_SUGGESTIONS, EVENT_LETTER_ENTERED];

}).call(this);
}, "views/dropdown": function(exports, require, module) {module.exports = function(__obj) {
  if (!__obj) __obj = {};
  var __out = [], __capture = function(callback) {
    var out = __out, result;
    __out = [];
    callback.call(this);
    result = __out.join('');
    __out = out;
    return __safe(result);
  }, __sanitize = function(value) {
    if (value && value.ecoSafe) {
      return value;
    } else if (typeof value !== 'undefined' && value != null) {
      return __escape(value);
    } else {
      return '';
    }
  }, __safe, __objSafe = __obj.safe, __escape = __obj.escape;
  __safe = __obj.safe = function(value) {
    if (value && value.ecoSafe) {
      return value;
    } else {
      if (!(typeof value !== 'undefined' && value != null)) value = '';
      var result = new String(value);
      result.ecoSafe = true;
      return result;
    }
  };
  if (!__escape) {
    __escape = __obj.escape = function(value) {
      return ('' + value)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
    };
  }
  (function() {
    (function() {
      var item, _i, _len, _ref;
    
      __out.push('<ul id="search_autocomplete" class="ui-autocomplete ui-menu ui-widget ui-widget-content ui-corner-all b-search-dropdown_group-autocomplete">\n    ');
    
      if (this.items) {
        __out.push('\n    ');
        _ref = this.items;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          item = _ref[_i];
          __out.push('\n        <li class="ui-menu-item">\n            <a  class="ui-corner-all item"\n                data-class="');
          __out.push(__sanitize(item["class"]));
          __out.push('"\n                data-href="');
          __out.push(__sanitize(item.href));
          __out.push('">\n                    ');
          __out.push(__sanitize(item.label));
          __out.push('\n            </a>\n        </li>\n    ');
        }
        __out.push('\n    ');
      }
    
      __out.push('\n</ul>\n');
    
    }).call(this);
    
  }).call(__obj);
  __obj.safe = __objSafe, __obj.escape = __escape;
  return __out.join('');
}}, "views/group_dropdown": function(exports, require, module) {module.exports = function(__obj) {
  if (!__obj) __obj = {};
  var __out = [], __capture = function(callback) {
    var out = __out, result;
    __out = [];
    callback.call(this);
    result = __out.join('');
    __out = out;
    return __safe(result);
  }, __sanitize = function(value) {
    if (value && value.ecoSafe) {
      return value;
    } else if (typeof value !== 'undefined' && value != null) {
      return __escape(value);
    } else {
      return '';
    }
  }, __safe, __objSafe = __obj.safe, __escape = __obj.escape;
  __safe = __obj.safe = function(value) {
    if (value && value.ecoSafe) {
      return value;
    } else {
      if (!(typeof value !== 'undefined' && value != null)) value = '';
      var result = new String(value);
      result.ecoSafe = true;
      return result;
    }
  };
  if (!__escape) {
    __escape = __obj.escape = function(value) {
      return ('' + value)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
    };
  }
  (function() {
    (function() {
      var i, item, _i, _j, _len, _len1, _ref, _ref1;
    
      __out.push('<div class="b-search-dropdown_group">\n    ');
    
      if (this.items) {
        __out.push('\n    ');
        _ref = this.items;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          item = _ref[_i];
          __out.push('\n        <div class="group_items_wrapper">\n            <ul class="group-items">\n                ');
          _ref1 = item.children;
          for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
            i = _ref1[_j];
            __out.push('\n                    <li>\n                        <a  class="item"\n                            data-class="');
            __out.push(__sanitize(i["class"]));
            __out.push('"\n                            data-href="');
            __out.push(__sanitize(i.href));
            __out.push('">\n                            ');
            __out.push(__sanitize(i.label));
            __out.push('\n                        </a>\n                    </li>\n                ');
          }
          __out.push('\n            </ul>\n        </div>\n        <div class="group_attributes">\n            <p class="title">');
          __out.push(__sanitize(item.label));
          __out.push('</p>\n        </div>\n    ');
        }
        __out.push('\n    ');
      }
    
      __out.push('\n</div>\n');
    
    }).call(this);
    
  }).call(__obj);
  __obj.safe = __objSafe, __obj.escape = __escape;
  return __out.join('');
}}
});
