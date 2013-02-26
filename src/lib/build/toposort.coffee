toposort = (modules, ctx) ->
    modules_list = (m for name, m of modules)

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
            message = "Failed to load dependencies or cyclic imports"
            + "[#{(modules_names.filter (m)-> m not in ordered_modules_names).join(',')}]"
            ctx.fb.scream message

        else
            reduce_func = (a, b) ->
                a[b] = unless b of a then 1 else a[b]+1
                a

            ctx.fb.scream "Cyclic dependences found #{(k for k,v of (ordered_modules_names.reduce reduce_func, {}) if v > 1)}"

        throw "Toposort failed"

    ordered_modules

module.exports = {toposort}