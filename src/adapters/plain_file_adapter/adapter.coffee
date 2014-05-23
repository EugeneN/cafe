# Plain old javascript file adaptor blah blah
fs = require 'fs'
path = require 'path'
{is_file, has_ext, get_mtime, and_, fn_without_ext} = require '../../lib/utils'
{say, shout, scream, whisper} = (require '../../lib/logger') "Adaptor/javascript>"
async = require 'async'
cs = require 'coffee-script'

{COFFEESCRIPT_EXT, CB_SUCCESS} = require '../../defs'

get_paths = (ctx) ->
    app_root = path.resolve ctx.own_args.app_root
    module_name = ctx.module.path

    source_fn: path.resolve app_root, module_name
    target_fn: path.resolve app_root, module_name


module.exports = do ->

    match = (ctx) ->
        {source_fn} = get_paths ctx
        (is_file source_fn) and ((path.extname source_fn) in ['.coffee', '.js', '.eco', '.jsx'])

    match.async = (ctx, cb) ->
        {source_fn} = get_paths ctx
        async.parallel [((is_file_cb) -> is_file.async source_fn, is_file_cb),
            ((is_file_cb) -> is_file_cb CB_SUCCESS, (path.extname source_fn) in ['.coffee', '.js', '.eco', '.jsx'])],
        (err, res) ->
            if not err and (and_ res...)
                cb CB_SUCCESS, true
            else
                cb CB_SUCCESS, false

    make_adaptor = (ctx) ->
        type = 'plain_javascript_file'

        get_deps = (recipe_deps, cb) ->
            module_name = ctx.own_args.mod_name

            for group, deps of recipe_deps
                if group is module_name
                    # making copy here because dependencies changed in toposort
                    group_deps = deps.concat()

            cb CB_SUCCESS, (group_deps or [])

        harvest = (cb) ->
            {target_fn} = get_paths ctx

            if is_file target_fn

                {coffee, eco, js, jsx} = require '../../lib/compiler/compilers'
                compiler = ctx.cafelib.make_compiler [coffee, eco, js, jsx]
                compiler.compile.async [target_fn], (err, compiled) ->
                    unless err
                        compiled_result = compiled.map ({path: p, source}) ->
                            {filename: ctx.module.name, source: source}

                        cb err, {sources:compiled_result, ns:''}
                    else
                        cb err
            else
                cb CB_SUCCESS, undefined

        last_modified = (cb) ->
            {source_fn} = get_paths ctx
            cb CB_SUCCESS, (get_mtime source_fn)

        {type, get_deps, harvest, last_modified}

    {match, make_adaptor}
