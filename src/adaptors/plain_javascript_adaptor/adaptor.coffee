# Plain old javascript file adaptor blah blah
fs = require 'fs'
path = require 'path'
{is_file, has_ext, get_mtime, and_} = require '../../lib/utils'
{say, shout, scream, whisper} = (require '../../lib/logger') "Adaptor/javascript>"
async = require 'async'

{JS_JUST_EXT, CB_SUCCESS} = require '../../defs'

get_paths = (ctx) ->
    app_root = path.resolve ctx.own_args.app_root
    module_name = ctx.own_args.mod_name

    {
        source_fn: path.resolve app_root, module_name
        target_fn: path.resolve app_root, module_name
    }

module.exports = do ->

    match = (ctx) ->
        {source_fn} = get_paths ctx
        (is_file source_fn) and (has_ext source_fn, JS_JUST_EXT)

    match.async = (ctx, cb) ->
        {source_fn} = get_paths ctx
        async.parallel [((is_file_cb) -> is_file.async source_fn, is_file_cb),
                        ((is_file_cb) -> has_ext.async source_fn, JS_JUST_EXT, is_file_cb)],
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
                source = fs.readFileSync target_fn
                cb CB_SUCCESS, {sources: {filename: target_fn, source:source, type:"plainjs"}}, "COMPILE_MAYBE_SKIPPED"
            else
                cb CB_SUCCESS, undefined

        last_modified = (cb) ->
            {source_fn} = get_paths ctx
            cb CB_SUCCESS, (get_mtime source_fn)

        {type, get_deps, harvest, last_modified}

    {match, make_adaptor}

