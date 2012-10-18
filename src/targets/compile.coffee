help = [
    """
    Compiles modules using appropriate adapters.
    Skips a module if it hasn't changed since the last time by default.

    Parameters:
        - src        - full path to a module. Other path arguments will be ignored 
                       should this argument be specified,
                       
        - app_root   - base path for compiling.
                       (Note that target compile path is set by the slug.json from
                       base path dir),

        - mod_name   - module name,

        - js_path    - dir to put compiled file to,

        - mod_suffix - suffix to put between app_root and mod_name,

        - t          - compile tests (default false),
        - f          - force compile without checking if there was any changes in files.
    """
]

fs = require 'fs'
path = require 'path'
async = require 'async'

{is_file} = require '../lib/utils'
get_adaptors = require '../lib/adaptor'
{make_target} = require '../lib/target'
{say, shout, scream, whisper} = (require '../lib/logger') 'Compile>'


compile = (ctx, cb) ->
    unless (ctx.own_args.app_root and ctx.own_args.mod_name) or ctx.own_args.src
        scream "app_root/mod_name or src arguments missing"
        return cb 'ctx_error'

    app_root = ctx.own_args.app_root
    mod_name = ctx.own_args.mod_name

    do_it_factory = (adaptor_factory, mapper_cb) ->
        (err, matches) ->
            if not err and matches
                mapper_cb (adaptor_factory.make_adaptor ctx)
                
            else
                mapper_cb undefined

    mapper = (adaptor_factory, mapper_cb) ->
        adaptor_factory.match.async ctx, (do_it_factory adaptor_factory, mapper_cb)

    done = (results...) ->
        adaptr = (results.filter (x) -> x isnt undefined)[0]

        if adaptr
            adaptr.harvest cb
        else
            ctx.fb.scream "No adaptor found" # TODO add module name here
            cb 'adaptor_error'

    async.map get_adaptors(), mapper, done


module.exports = make_target "compile", compile, help

