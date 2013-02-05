get_module = (
    path=""
    alias=""
    deps=""
    type="commonjs"
    location="fs"
    ) ->

    {name, path, deps, type, location}

construct_module = (meta) ->
    if (typeof meta) is "string"
        module = get_module(alias=meta, path=meta)
