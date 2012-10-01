fs = require 'fs'
path = require 'path'
async = require 'async'
mkdirp = require 'mkdirp'
{map, reduce} = require 'functools'


get_adaptors = require './adaptor'
{read_json_file, extend} = require '../lib/utils'
{flatten, is_dir, is_file, extend, newest, get_mtime} = require('./utils')
{say, shout, scream, whisper} = (require './logger') "lib-bundle>"

{SLUG_FN, FILE_ENCODING, BUILD_FILE_EXT, RECIPE, VERSION, EOL, CB_SUCCESS,
 BUNDLE_HDR, BUNDLE_ITEM_HDR, BUNDLE_ITEM_FTR} = require '../defs'


resolve_deps = ({modules, app_root, recipe_deps, ctx}, resolve_deps_cb) ->
    ''' Resolves deps and assigns an adaptor to each module '''

    adaptors = get_adaptors() # sync for now
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
                 sorted_modules_list, build_root, ctx, cb}) ->

    get_target_fn = ->
        path.resolve build_root, realm, (bundle_name + BUILD_FILE_EXT)

    write_bundle = (file_list, cb) ->
        read_file = (fn, cb) ->
            fs.readFile fn, FILE_ENCODING, (err, data) ->
                if err
                    cb CB_SUCCESS, [fn, "/* Can't read: #{err} */"]
                else
                    cb CB_SUCCESS, [fn, data]

        merge = (a, [fn, fc]) ->
            reduce ((x, y) -> x + y), [a, (BUNDLE_ITEM_HDR fn), fc, BUNDLE_ITEM_FTR]

        done = (err) ->
            if err
                ctx.fb.scream """Failed to write bundle #{realm}/#{bundle_name}#{BUILD_FILE_EXT}:
                                 #{err}
                              """
                cb 'target_error', err
            else
                ctx.fb.say "Bundle #{realm}/#{bundle_name}#{BUILD_FILE_EXT} built."
                cb()

        do_it = (err) ->
            if err
                cb 'fs_error', err
            else
                map.async read_file, file_list, (err, out) ->
                    (fs.writeFile get_target_fn(),
                                  (BUNDLE_HDR + (reduce merge, ([''].concat out))),
                                  FILE_ENCODING,
                                  done)

        mkdirp (path.resolve build_root, realm), do_it

    seq = (m.adaptor.harvest for m in sorted_modules_list)
    seq2 = (m.adaptor.last_modified for m in sorted_modules_list)

    opts = if force_compile
        full_args:
            compile:
                f: true
        own_args:
            f: true
    else
        {}

    seq_harvester = (adaptor_worker, cb) -> adaptor_worker cb, opts

    seq2_harvester = (adaptor_worker, cb) -> adaptor_worker cb

    done = (err, results) ->
        if err
            ctx.fb.scream "Level 2 build sequence error: #{err}"
            cb? 'target_error', err

        else
            write_cb = (not_changed) ->
                (err, res) ->
                    if err
                        cb err, res
                    else
                        cb CB_SUCCESS, [realm, bundle_name, not_changed]

            if force_bundle
                write_bundle (flatten results), (write_cb false)

            else
                done_seq2 = (err, result) ->
                    if err
                        ctx.fb.scream "Error getting last_modified: #{err}"
                        cb? 'target_error', err

                    else
                        recipe_mtime = (get_mtime (path.resolve ctx.own_args.app_root,
                                                                (ctx.own_args.formula or RECIPE)))

                        max_src_mtime = newest [result..., [recipe_mtime]...]

                        target_mtime = try
                            get_mtime get_target_fn()
                        catch e
                            0

                        unless max_src_mtime < target_mtime
                            write_bundle (flatten results), (write_cb false)
                        else
                            ctx.fb.shout "Bundle #{realm}/#{bundle_name} still hot"
                            write_bundle (flatten results), (write_cb true)

                # maybe bundle check
                async.map seq2, seq2_harvester, done_seq2

    # Build level 2 entry point
    async.map seq, seq_harvester, done


module.exports = {resolve_deps, toposort, build_bundle}
