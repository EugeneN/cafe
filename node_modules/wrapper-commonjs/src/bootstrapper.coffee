"""
Simple common js bootstrapper.
Inspired by stitch.
"""

unless this.require
    modules = {}
    cache = {}

    unless window.bootstrapper
        doc = window.document
        add = if doc.addEventListener then 'addEventListener' else 'attachEvent'
        rem = if doc.addEventListener then 'removeEventListener' else 'detachEvent'
        pre = if doc.addEventListener then '' else 'on'

        window.bootstrapper =
            init_queue: []
            document_ready_queue: []
            document_loaded_queue: []
            modules: modules
            run_queue: (queue) ->
                while f = queue.shift()
                    f()
            run_init_queue: ->
                window.bootstrapper.run_queue window.bootstrapper.init_queue

        if doc.readyState is 'complete'
            # run everything if all events has been fired already
            window.bootstrapper.run_queue window.bootstrapper.document_ready_queue
            window.bootstrapper.run_queue window.bootstrapper.document_loaded_queue

        else
            # postpone queues processing
            doc[add](pre + 'DOMContentLoaded',
                     -> window.bootstrapper.run_queue window.bootstrapper.document_ready_queue)
            window[add](pre + 'load',
                        -> window.bootstrapper.run_queue window.bootstrapper.document_loaded_queue)




    partial = (fn) ->
        partial_args = Array::slice.call arguments
        partial_args.shift()
        ->
            [new_args, arg] = [[], 0]

            for a, i in partial_args
                if partial_args[i] is undefined
                    new_args.push arguments[arg++]
                else
                    new_args.push partial_args[i]
            fn.apply this, new_args



    require = (name, root, ns) ->
        # special case
        if name is 'bootstrapper'
            return window.bootstrapper

        path = expand(root, name)

        if ns? and !(modules[path] || modules[(expand(path, './index'))]) # TODO: handle when module is not loaded.
            path = "#{ns}/#{expand '', name}"

        module = cache[path]

        if module
            module.exports
        else if fn = modules[path] or modules[path=expand(path, './index')]
            module =
                id: path
                exports: {}
            try
                cache[path] = module
                fn module.exports, module
                module.exports
            catch e
                delete cache[path]
                throw e
        else
            throw "module '#{name}' is not found"


    expand = (root, name) ->
        results = []

        if /^\.\.?(\/|$)/.test name
            parts = [root, name].join('/').split('/')
        else
            parts = name.split '/'

        for i in [0..parts.length - 1]
            part = parts[i]

            if part is '..'
                results.pop()
            else if part != '.' && part != ''
                results.push part

        results.join '/'


    diranme = (path) -> path.split('/')[0..-1].join '/'


    this.require = (name) -> require name, ''


    this.require.define = (ns, bundle) ->
        _require = partial(require, undefined, undefined, ns)

        for key, value of bundle
            _key =  if ns then "#{ns}/#{key}" else key
            modules[_key] = partial(value, undefined, _require, undefined)
            undefined
        undefined

