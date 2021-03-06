clone = (obj) -> JSON.parse JSON.stringify obj

toposort = (modules) ->

    reducer = (a, b) ->
        ret = {}
        ret['name'] = b[0]
        ret['deps'] = b[1]
        a.concat [ret]

    _modules = modules.map((m) -> [(clone m.name), (clone m.deps)]).reduce reducer, []

    modules_list = (m for name, m of _modules)

    have_no_dependencies = (m for m in modules_list when m.deps.length is 0)
    ordered_modules = []

    while have_no_dependencies.length > 0
        cur_module = have_no_dependencies.pop()
        ordered_modules.push cur_module

        modules_without_deps = have_no_dependencies.concat ordered_modules

        for m in modules_list when not (m in modules_without_deps)
            # Testing if m depend on cur_module
            pos = m.deps.indexOf(cur_module.name)

            # If yes, removing this dependency
            if pos? >= 0
                delete m.deps[pos]

                # if m has no more deps
                if (dep for dep of m.deps).length == 0
                    have_no_dependencies.push m

    unless ordered_modules.length is modules_list.length
        modules_names = modules_list.map (i) -> i.name
        ordered_modules_names = ordered_modules.map (i) -> i.name

        if modules_names.length > ordered_modules_names.length # we'v got trouble with dependencies
            message = "Failed to load dependencies or cyclic imports"\
                + "[#{(modules_names.filter (m)-> m not in ordered_modules_names).join(',')}]"
            throw message

        else
            reduce_func = (a, b) ->
                a[b] = unless b of a then 1 else a[b]+1
                a

            throw "Cyclic dependences found #{(k for k,v of (ordered_modules_names.reduce reduce_func, {}) if v > 1)}"

        throw "Toposort failed"

    ordered_modules.map (m) -> (modules.filter((mod) -> mod.name is m.name))[0]


module.exports = {toposort}