fs = require 'fs'
path = require 'path'
async = require 'async'
mkdirp = require 'mkdirp'
{map, reduce} = require 'functools'
{wrap_bundle, wrap_modules} = require 'wrapper-commonjs'
{get_modules_cache} = require './modules_cache'


get_adaptors = require './adaptor'
{read_json_file, extend} = require '../lib/utils'
{flatten, is_dir, is_file, extend, newest, get_mtime} = require('./utils')
{say, shout, scream, whisper} = (require './logger') "lib-bundle>"

{SLUG_FN, FILE_ENCODING, BUILD_FILE_EXT, RECIPE, VERSION, EOL, CB_SUCCESS,
 BUNDLE_HDR, BUNDLE_ITEM_HDR, BUNDLE_ITEM_FTR, EVENT_BUNDLE_CREATED, FILE_TYPE_COMMONJS,
 FILE_TYPE_PLAINJS } = require '../defs'


resolve_deps = ({modules, app_root, recipe_deps, ctx}, resolve_deps_cb) ->
    ''' Resolves deps and assigns an adaptor to each module '''

    adaptors = get_adaptors() # sync for now

    unless adaptors.length > 0
        throw 'No adaptors found for build'

    app_root = path.resolve ctx.own_args.app_root

    process_module = (module_name, process_module_cb) ->
        args =
            own_args:
                mod_name: module_name

        new_ctx = extend ctx, args

        find_adaptor = (adaptor_factory, find_adaptor_cb) ->
            adaptor_factory.match.async new_ctx, (err, match) ->
                if match
                    adaptor = adaptor_factory.make_adaptor new_ctx

                    adaptor.get_deps recipe_deps, (err, module_deps) ->
                        # FIXME should modules without deps be skipped here?
                        if err
                            find_adaptor_cb err, undefined

                        else
                            spec =
                                name: module_name
                                deps: module_deps
                                adaptor: adaptor

                            find_adaptor_cb CB_SUCCESS, spec
                else
                    find_adaptor_cb err, undefined

        async.map adaptors, find_adaptor, (err, found_modules_list) ->
            f = found_modules_list.filter (itm) -> itm isnt undefined
            process_module_cb err, f[0]

    if modules
        async.map modules, process_module, (err, found_modules_list) ->
            found_modules = {}

            found_modules_list.map (mod_spec) ->
                if mod_spec isnt undefined
                    found_modules[mod_spec.name] = mod_spec

            resolve_deps_cb err, found_modules
    else
        resolve_deps_cb CB_SUCCESS, [] # ???

toposort = (debug_info, modules) ->
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
        throw "Cyclic dependency or unknown module found in #{debug_info.realm}/#{debug_info.bundle.name}: " \
            + "#{(m.name for m in modules_list when m not in (i.name for i in ordered_modules)).join(', ')}"

    ordered_modules


build_bundle = ({realm, bundle_name, bundle_opts, force_compile, force_bundle,
                 sorted_modules_list, build_root, cache_root, ctx, build_bundle_cb}) ->

    modules_cache = get_modules_cache cache_root

    get_target_fn = ->
        path.resolve (path.resolve build_root, realm), (bundle_name + BUILD_FILE_EXT)

    write_bundle = (results, cb) ->
        done = (err) ->
            if err
                ctx.fb.scream """Failed to write bundle #{realm}/#{bundle_name}#{BUILD_FILE_EXT}:
                                 #{err}
                              """

                cb 'target_error', err
            else
                ctx.fb.say "Bundle #{realm}/#{bundle_name}#{BUILD_FILE_EXT} built."
                cb CB_SUCCESS, [realm, bundle_name, false]

        do_it = (err) ->
            if err
                cb 'fs_error', err
            else
                unless ctx.own_args.just_compile
                    fs.writeFile(
                        get_target_fn()
                        wrap_bundle((wrap_modules results), BUNDLE_HDR)
                        FILE_ENCODING
                        done
                    )
                else
                    ctx.fb.whisper "'just_compile mode' is on, so no result bundle was written"
                    ctx.emitter.emit EVENT_BUNDLE_CREATED, results
                    done null

        unless ctx.own_args.just_compile
            build_dir_path = (path.resolve build_root, realm)
            ctx.fb.whisper "Creating build dir #{build_dir_path}"
            mkdirp build_dir_path, do_it
        else
            ctx.fb.whisper "Skip creating build dir"
            do_it null

    get_bundle_mtime = () ->
        newest [
            (try
                get_mtime get_target_fn()
            catch e
                0)
            (get_mtime (path.resolve ctx.own_args.app_root,
                (ctx.own_args.formula or RECIPE)))
        ]

    module_handler = (module, cb) ->
        module.adaptor.last_modified (err, module_mtime) ->
            if ([(module_mtime > (modules_cache.get_cache_mtime module))
                 (ctx.own_args.f is true)
                 (module.adaptor.type is 'recipe')].reduce((a, b) -> a or b)) # TODO: remove condition for recipe module.
                                                                              #  this logic must be out of bundler scope
                ctx.fb.say "Harvesting module #{module.name}"

                need_to_rebuild_bundle = not (module.adaptor.type is 'recipe')

                module.adaptor.harvest (err, compiled_results) ->
                    module.source = compiled_results
                    ctx.fb.say "Saving #{module.name} to cache."
                    modules_cache.save module
                    cb CB_SUCCESS, [compiled_results, need_to_rebuild_bundle]
            else
                ctx.fb.shout "Skip harvesting module #{module.name}, taking source from modules cache"
                cb CB_SUCCESS, [modules_cache.get(module.name).source, false]

    done = (err, raw_results) ->
        """
        @raw_results : [[source, need_to_rebuild_bundle] ... ]
        """

        unless raw_results.len
            ctx.fb.shot "Bundle #{bundle_name} is empty ..."
            (build_bundle_cb CB_SUCCESS, [realm, bundle_name, true]) 
            return

        need_to_rebuild_bundle = raw_results.map((r) -> r[1]).reduce (a, b) -> a or b

        if need_to_rebuild_bundle
            results = raw_results.map((r)-> r[0]).filter (r) -> r?
            write_bundle (flatten results), build_bundle_cb
        else
            ctx.fb.shout "Bundle #{bundle_name} is still hot, skip build"
            build_bundle_cb CB_SUCCESS, [realm, bundle_name, true]

    async.map sorted_modules_list, module_handler, done


module.exports = {resolve_deps, toposort, build_bundle}
