unless this.require
    modules = {}
    cache = {}


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
        if ns? and !((expand root, name) of modules) # TODO: handle when module is not loaded.
            name = "#{ns}/#{expand '', name}"

        path = expand(root, name)
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

        for key, value of bundle # make auto require onload
            _key =  if ns then "#{ns}/#{key}" else key
            modules[_key] {}, {}
            undefined

        undefined