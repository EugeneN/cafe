Spine = require('spine')
$ = Spine.$

keyCode=$.ui.keyCode

EVENT_INPUT_ITEM_SELECT = 'input_item_selected'
EVENT_REQUEST_SUGGESTIONS = 'input_request_suggestions'
EVENT_LETTER_ENTERED = 'input_letter_entered'

class PAutocompleteInputController extends Spine.Controller
    constructor: ->
        ###
        Accepts:
        @el: main element.
        @dropdown: Object for displaying recieved items.
        ###
        super
        @dropdown.bind 'dropdown_deactivate', => @el.val(@_last_value)

        @_popup_active = false
        @_last_value = ''

        $(@el).keyup @_event_keyup
        $(@el).keydown @_event_keydown


    process_suggest_items: (items) =>
        if items.length > 0
            @_show_popup(items)
        else
            @_hide_popup()



    _event_keydown:(ev) =>
        switch ev.keyCode
            when keyCode.UP
                event.preventDefault()
                @dropdown.item_up()
            when keyCode.DOWN
                @dropdown.item_down()
            when keyCode.ENTER
                event.preventDefault()
        undefined


    _event_keyup:(ev) =>
        unless @_control_buttons_handle(ev)
            @trigger EVENT_LETTER_ENTERED

            if @el.val().length+1 <= @min_input_chars
                @_hide_popup()
            else
                @_last_value = @el.val()

                timeout_func = =>
                    @trigger EVENT_REQUEST_SUGGESTIONS, @el.val()

                if @_timeout_handler
                    clearTimeout @_timeout_handler

                @_timeout_handler = setTimeout timeout_func, @delay

        undefined


    _control_buttons_handle: (event) ->
        switch event.keyCode
            when keyCode.UP
                break
            when keyCode.DOWN
                break
            when keyCode.ESCAPE
                @el.val(@_last_value)
                @_hide_popup()
            when keyCode.ENTER
                event.preventDefault()
                @trigger EVENT_INPUT_ITEM_SELECT, @dropdown.get_selected_item()

            else
                return false
        true


    _hide_popup: =>
        if @_popup_active
            @dropdown.hide_popup()
            @_popup_active = false


    _show_popup: (items) =>
        @_popup_active = true unless @_popup_active
        @dropdown.show_popup(items)


module.exports = [
    PAutocompleteInputController,
    EVENT_INPUT_ITEM_SELECT,
    EVENT_REQUEST_SUGGESTIONS,
    EVENT_LETTER_ENTERED
]
