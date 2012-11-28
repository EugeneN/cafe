# Plain coffescript file adaptor blah blah
fs = require 'fs'
path = require 'path'
cs = require 'coffee-script'
{
    is_file
    has_ext
    get_mtime
    newer
    get_result_filename
    and_
} = require '../../lib/utils'
{say, shout, scream, whisper} = (require '../../lib/logger') "Adaptor/coffee>"
async = require 'async'

{FILE_ENCODING, TMP_BUILD_DIR_SUFFIX, CS_EXT, JS_EXT, CB_SUCCESS, 
 COFFEESCRIPT_EXT} = require '../../defs'


get_target_fn = (app_root, module_name) ->
    (path.resolve app_root,
                  TMP_BUILD_DIR_SUFFIX,
                  (module_name.replace (new RegExp "#{CS_EXT}$"), '') + JS_EXT)


get_paths = (ctx) ->
    app_root = path.resolve ctx.own_args.app_root
    module_name = ctx.own_args.mod_name

    src = path.resolve (ctx.own_args.src or (path.resolve app_root, module_name))

    target_fn = if ctx.own_args.js_path
        get_result_filename src, ctx.own_args.js_path, CS_EXT, JS_EXT
    else
        (get_target_fn (path.resolve ctx.own_args.app_root),
                       (path.basename module_name))

    {
        source_fn: src or (path.resolve app_root, module_name)
        target_fn: target_fn
    }

module.exports = do ->

    match = (ctx) ->
        {source_fn} = get_paths ctx
        (is_file source_fn) and (has_ext source_fn, COFFEESCRIPT_EXT)

    match.async = (ctx, cb) ->
        {source_fn} = get_paths ctx
        
        async.parallel [((is_file_cb) -> is_file.async source_fn, is_file_cb),
                        ((has_ext_cb) -> has_ext.async source_fn, COFFEESCRIPT_EXT, has_ext_cb)],
                        (err, res) ->
                            if not err and (and_ res...)
                                cb CB_SUCCESS, true
                            else
                                cb CB_SUCCESS, false

    make_adaptor = (ctx) ->
        type = 'plain_coffeescript_file'

        get_deps = (recipe_deps, cb) ->
            module_name = ctx.own_args.mod_name

            for group, deps of recipe_deps
                if group is module_name
                    # making copy here because dependencies changed in toposort
                    group_deps = deps.concat()

            cb CB_SUCCESS, (group_deps or [])

        harvest = (cb) ->
            {source_fn, target_fn} = get_paths ctx

            fs.exists source_fn, (exists) ->
                if exists
                    if ctx.own_args.f or (newer source_fn, target_fn)
                        fs.readFile source_fn, FILE_ENCODING, (err, data) ->
                            if err
                                ctx.fb.scream "Can't read file #{source_fn}: #{err}"
                                cb CB_SUCCESS, undefined
                            else
                                js = try
                                    cs.compile data.toString()
                                catch e

                                    try
                                        fs.unlinkSync target_fn
                                    catch e

                                    ctx.fb.scream "Error compiling #{source_fn}: #{e}"
                                    scream "Error compiling #{source_fn}: #{e}"
                                    whisper "#{e.stack}"

                                    cb 'adaptor_error', e

                                fs.writeFile target_fn, js, FILE_ENCODING, (err) ->
                                    if err
                                        ctx.fb.scream "Can't write file #{target_fn}: #{err}"
                                        cb CB_SUCCESS, undefined
                                    else
                                        ctx.fb.say "#{target_fn} brewed."
                                        cb CB_SUCCESS, target_fn

                    else
                        ctx.fb.shout "#{source_fn} still hot"
                        cb CB_SUCCESS, target_fn, "COMPILE_MAYBE_SKIPPED"

                else
                    ctx.fb.scream "No such file: #{source_fn}"
                    cb CB_SUCCESS, undefined

        last_modified = (cb) ->
            {source_fn} = get_paths ctx
            cb CB_SUCCESS, (get_mtime source_fn)

        {type, get_deps, harvest, last_modified}

    {match, make_adaptor}
