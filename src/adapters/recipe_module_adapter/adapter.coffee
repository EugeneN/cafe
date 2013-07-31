fs = require 'fs'
path = require 'path'
{exec, spawn, fork} = require 'child_process'
{maybe_build, is_dir, is_file, has_ext, and_,
 get_mtime, newer, walk, newest, extend, is_array} = require '../../lib/utils'

LOG_PREFIX = 'UI/RecipeModule>'
logger = (require '../../lib/logger') LOG_PREFIX
{green, yellow, red} = logger

async = require 'async'
events = require 'events'
{partial} = require 'libprotein'


{FILE_ENCODING, TMP_BUILD_DIR_SUFFIX, JS_EXT,
  NODE_PATH, CB_SUCCESS, RECIPE} = require '../../defs'


get_target_fn = (js_path, app_root, target_fn) ->
    if js_path
        path.resolve js_path, target_fn
    else
        (path.resolve app_root,
                      TMP_BUILD_DIR_SUFFIX,
                      target_fn)


get_paths = (ctx) ->
    app_root = path.resolve ctx.own_args.app_root
    build_root = path.resolve ctx.own_args.build_root
    module_name = ctx.module.path
    src = ctx.own_args.src
    js_path = ctx.own_args.js_path
    mod_src = src or path.resolve app_root, module_name
    recipe = path.resolve mod_src, RECIPE
    target_fn = path.basename module_name + JS_EXT
    target_full_fn = get_target_fn js_path, app_root, target_fn
    build_root = js_path or path.resolve build_root
    {mod_src, recipe, target_fn, target_full_fn, build_root}


module.exports = do ->
    match = (ctx) ->
        {mod_src, recipe} = get_paths ctx
        (is_dir mod_src) and (is_file recipe)

    match.async = (ctx, cb) ->
        {mod_src, recipe} = get_paths ctx
        async.parallel [((is_dir_cb) -> is_dir.async mod_src, is_dir_cb), 
                        ((is_file_cb) -> is_file.async recipe, is_file_cb)],
                        (err, res) ->
                            if not err and (and_ res...)
                                cb CB_SUCCESS, true
                            else
                                cb CB_SUCCESS, false

    make_adaptor = (ctx) ->
        type = 'recipe'

        get_deps = (recipe_deps, cb) ->
            module_name = ctx.own_args.mod_name

            for group, deps of recipe_deps
                if group is module_name
                    # making copy here because dependencies changed in toposort
                    group_deps = deps.concat()

            cb CB_SUCCESS, (group_deps or [])

        harvest = (harvest_cb, opts={}) ->
            {mod_src, target_full_fn, target_fn, build_root} = get_paths ctx

            check_maybe_do = (cb) ->
              maybe_build mod_src, target_full_fn, (changed, filename) ->
                if changed or (extend ctx, opts).own_args.f
                  cb()
                else
                  cb 'MAYBE_SKIP'

            do_recipe = (cb) ->
              ctx.fb.say "Harvesting recipe module"
              emitter = new events.EventEmitter
              cafe_factory = require '../../cafe'
              {ready} = cafe_factory emitter

              exit_cb = (status_code, bundles) ->
                cb null, bundles

              {go} = ready {exit_cb, fb}

              argv = {build: {
                app_root: mod_src
                build_root: build_root
                just_compile: true
                f: ctx.own_args.f
                }
              }

              go {args: argv}

            done = (err, res) ->
                switch err
                    when null
                      ctx.fb.say "Recipe module #{mod_src} was brewed"
                      harvest_cb CB_SUCCESS, res
                    when "MAYBE_SKIP"
                      ctx.fb.shout "maybe skipped"
                      harvest_cb null, res
                    else
                      ctx.fb.scream "Error during compilation of recipe module #{mod_src} err - #{err}"
                      harvest_cb err, res

            async.waterfall([
              check_maybe_do
              do_recipe]
              done)


        last_modified = (cb) ->
            cb CB_SUCCESS, 0

        {type, get_deps, harvest, last_modified}

    {match, make_adaptor}
