Spine = require('spine')
$ = Spine.$

[
    PAutocompleteDropdownController,
    EVENT_DROPDOWN_ITEM_SELECT,
    EVENT_DROPDOWN_ITEM_HIGHLIGHT,
    EVENT_DROPDOWN_POPUP_SHOW
] = require('controllers/PAutocompleteDropdownController')

[
    PAutocompleteInputController,
    EVENT_INPUT_ITEM_SELECT,
    EVENT_REQUEST_SUGGESTIONS,
    EVENT_LETTER_ENTERED
] = require('controllers/PAutocompleteInputController')

DEFAULT_DELAY = 300
DEFAULT_MIN_CHARS = 3
DEFAULT_ITEMS_SELECTOR = '.item'
EVENT_ITEM_SELECTED = 'PA.item_selected'

class PAutocompleteController extends Spine.Controller
    constructor: (options) ->
        super

        throw 'input_selector param is missing' unless 'input_selector' of options
        throw 'url param is missing' unless 'url' of options
        throw 'template param is missing' unless 'template' of options
        throw 'poup_selector param is missing' unless 'popup_selector' of options

        options.delay = DEFAULT_DELAY unless 'delay' of options
        options.min_input_chars = DEFAULT_MIN_CHARS unless 'min_input_chars' of options
        options.items_selector = DEFAULT_ITEMS_SELECTOR unless 'items_selector' of options

        @selected = options.selected_item_handler if options.selected_item_handler

        @build_suggest_params_handler = options.build_suggest_params_handler or @_get_default_suggest_params
        
        @form_id = options.form_id if 'form_id' of options
        @suggest_url = options.url

        @_dropdown = new PAutocompleteDropdownController(
            active_item_class: options.active_item_class,
            popup_selector: options.popup_selector,
            input_selector: options.input_selector,
            item_list_selector: options.items_selector,
            template: options.template
        )

        @_input = new PAutocompleteInputController(
            el: $(options.input_selector),
            suggest_url: options.url,
            dropdown: @_dropdown,
            min_input_chars: options.min_input_chars,
            delay: options.delay
        )

        @_input.bind EVENT_REQUEST_SUGGESTIONS, @process_suggest
        
        @_input.bind EVENT_INPUT_ITEM_SELECT, (item) =>
            @trigger EVENT_ITEM_SELECTED, item

        @_dropdown.bind EVENT_DROPDOWN_ITEM_HIGHLIGHT, (item) =>
            @_input.el.val item

        @_dropdown.bind EVENT_DROPDOWN_ITEM_SELECT, (item) =>
            @trigger EVENT_ITEM_SELECTED, item

        if @selected
            @bind EVENT_ITEM_SELECTED, @selected

        @process_highlight()


    on_item_selected: (handler) ->
        @bind EVENT_ITEM_SELECTED, handler


    process_suggest: =>
        @xhr.abort() if @xhr

        @xhr = $.ajax(
                url: @suggest_url,
                data: @build_suggest_params_handler(),
                success: (data) => @_input.process_suggest_items(data),
                error: (xhr, textStatus, err) => @log(textStatus:textStatus, error:err)
        )


    process_highlight: ->
        make_match_bold = =>
            return if @_input.el.val() is ""
            patt = new RegExp @_input.el.val(), "ig"

            for item in @_dropdown.items_list()
                j_item = $ item
                match = j_item.text().match patt
                j_item.html(j_item.text().replace patt, "<strong>#{match}</strong>")

        @_dropdown.bind EVENT_DROPDOWN_POPUP_SHOW,  make_match_bold
        @_input.bind EVENT_LETTER_ENTERED, make_match_bold


    _get_default_suggest_params: ->
        'term': @_input.el.val()


module.exports = PAutocompleteController
