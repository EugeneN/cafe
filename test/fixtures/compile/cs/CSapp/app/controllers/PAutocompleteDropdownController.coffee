Spine = require('spine')
$ = Spine.$

EVENT_DROPDOWN_ITEM_SELECT = 'dropdown_item_select'
EVENT_DROPDOWN_ITEM_HIGHLIGHT = 'dropdown_item_highlight'
EVENT_DROPDOWN_ITEM_DEACTIVATE = 'dropdown_item_deactivate'
EVENT_DROPDOWN_POPUP_SHOW = 'dropdown_popup_show'

DEFAULT_ACTIVE_CLASS = 'active'

class PAutocompleteDropdownController extends Spine.Controller
    constructor: ->
        super

        @logPrefix = '(PAutocompleteController)'

        throw "popup_selector param is missing" unless @popup_selector

        @active_item_class = DEFAULT_ACTIVE_CLASS unless @active_item_class

        @selected_index = 0

        $('body').append(@render())

        @dropdown_active = false

        # closing popup if clicked outside of the popup.
        close_if_click_outside_popup = (e) =>
            if $(e.target).parents(@popup_selector).length == 0 \
                    and '#' + $(e.target).attr('id') != @input_selector
                @hide_popup()
            true

        $(document).click close_if_click_outside_popup

        @el.click (ev) =>
            if @_check_if_item_from_target(ev)
                item = @_get_crossbrowser_event_target(ev)
                @selected_index = $(@item_list_selector).index(item)
                @highlight_item(@selected_index)

                @trigger EVENT_DROPDOWN_ITEM_SELECT, item.data()


    get_selected_item:->
        if @dropdown_active
            return  $(@items_list()[@selected_index]).data()
        else
            return null
            

    render: =>
        @html require @template


    _init_position: =>
        ### Method for calculating popup windown offset and width ###
        input_selector = $ @input_selector

        top = input_selector.offset().top + input_selector.outerHeight()
        left = input_selector.offset().left

        $(@popup_selector).outerWidth input_selector.outerWidth()

        $(@popup_selector).css {top:top, left: left}


    _check_if_item_from_target: (ev) ->
            item = @_get_crossbrowser_event_target(ev)
            classes = (".#{i}" for i in item.attr('class').split(' '))
            id = "##{item.attr('id')}"
            @item_list_selector in classes


    _get_crossbrowser_event_target: (ev) ->
        target = ev.target
        target = ev.srcElement unless target
        $ target


    show_popup: (items) =>
        @html(require(@template)({items}))
        @_init_position()

        hover_in = (ev)=>
            item = @_get_crossbrowser_event_target(ev)
            item.addClass(@active_item_class)

        hover_out = (ev)=>
            item = @_get_crossbrowser_event_target(ev)
            item.removeClass(@active_item_class)

        @el.find(@item_list_selector).hover(hover_in, hover_out)
        $(@el).show()
        @trigger EVENT_DROPDOWN_POPUP_SHOW


    hide_popup : =>
        @selected_index = 0
        $(@el).hide()
        @dropdown_active = false


    items_list: ->
        @el.find(@item_list_selector)


    item_up: =>
        #if first item
        if @dropdown_active and @selected_index == 0
            @dropdown_deactivate()
            return

        #if init item
        if not @dropdown_active and @selected_index == 0
            @dropdown_activate(false)
            return

        @selected_index -= 1
        @highlight_item(@selected_index)


    item_down: =>
        #check if first and dropdown deactivated
        if not @dropdown_active and @selected_index == 0
            @dropdown_activate()
            return

        #check if last and dropdown active.
        if @dropdown_active and @selected_index == @items_list().length - 1
            @dropdown_deactivate()
            return

        @selected_index += 1
        @highlight_item(@selected_index)


    highlight_item: (index) ->
        @items_list().removeClass(@active_item_class)
        $(@items_list()[index]).addClass(@active_item_class)

        @trigger EVENT_DROPDOWN_ITEM_HIGHLIGHT, $.trim $(@items_list()[index]).text()


    dropdown_activate: (top_active=true) ->
        if top_active
            @selected_index = 0
        else
            @selected_index = @items_list().length - 1

        @dropdown_active = true
        @highlight_item(@selected_index)


    dropdown_deactivate: ->
        @items_list().removeClass @active_item_class

        @dropdown_active = false

        @trigger 'dropdown_deactivate'
        @selected_index = 0


module.exports = [
    PAutocompleteDropdownController,
    EVENT_DROPDOWN_ITEM_SELECT,
    EVENT_DROPDOWN_ITEM_HIGHLIGHT,
    EVENT_DROPDOWN_POPUP_SHOW
]
