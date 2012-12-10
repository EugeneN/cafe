
fs = require 'fs'
path = require 'path'
{spawn} = require 'child_process'
{say, shout, scream, whisper} = (require './logger') 'Utils>'

{JS_PATTERN, SLUG_FN, FILE_ENCODING, CB_SUCCESS} = require '../defs'

read_slug = (p) ->
    slug_fn = path.resolve p, SLUG_FN

    # if fs.existsSync(slug_fn)
    JSON.parse(fs.readFileSync(slug_fn, FILE_ENCODING))
    # else
        # {}

walk = (dir, done) ->
    # concurrent async walk
    results = []

    fs.readdir(dir, (err, list) ->
        return done(err) if err

        pending = list.length
        return (done CB_SUCCESS, results) unless pending

        list.forEach(
            (file) ->
                file = path.join dir, file
                fs.stat(file, (err, stat) ->
                    if stat and stat.isDirectory()
                        walk file, (err, res) ->
                            results = results.concat res
                            (done CB_SUCCESS, results) unless --pending
                    else
                        results.push file
                        (done CB_SUCCESS, results) unless --pending

                )
        )
    )

flatten = (array, results = []) ->
    for item in array
        if Array.isArray(item)
            flatten(item, results)
        else
            results.push(item)

    results

toArray = (value = []) ->
    if Array.isArray(value) then value else [value]

is_array = (v) -> Array.isArray v

mtime_to_unixtime = (mtime_str) -> (new Date(mtime_str)).getTime()

get_mtime = (filename) ->
    stat = fs.statSync filename
    mtime_to_unixtime stat.mtime

get_mtime.async = (filename, cb) ->
    fs.stat filename, (err, stat) ->
        if err
            cb err
        else
            cb mtime_to_unixtime stat.mtime

newest = (l) -> Math.max.apply Math, l

maybe_build = (build_root, built_file, cb) ->

    dst_max_mtime = try
        get_mtime built_file
    catch e
        -1

    walk build_root, (err, results) ->
        if results
            try
                src_max_mtime = newest(
                    results.map (filename) -> get_mtime filename
                )

                should_recompile = dst_max_mtime < src_max_mtime
            catch ex
                should_recompile = true

            if should_recompile
                cb? true, built_file
            else
                cb? false, built_file
        else
            cb? false, built_file


camelize = (str) ->
    str.replace(/-|_+(.)?/g, (match, chr) ->
        if chr
            chr.toUpperCase()
        else
            ''
    ).replace(/^(.)?/, (match, chr) ->
        if chr
            chr.toUpperCase()
        else
            ''
    )

expandPath = (_path, dir) ->
    if path.basename _path is _path
        _path = dir + _path

    path.normalize _path


add = (args...) ->
    ''' Polymorphic (kind of) function to add arbitrary number of arguments.
        Dispatches types by the first argument.
        When adding objects, values for the same keys end up with the last one.
        Expect strange things to happen when adding values of different types.

        Most important: returns a new (frozen when possible) value,
        leaves arguments intact.
    '''
    first = args[0]

    unless first
        first

    else if Array.isArray first
        args.reduce (a, b) -> a.concat b

    else if first.toString() is '[object Object]'
        ret = args.reduce(
            (a, b) ->
                a[k] = v for own k, v of b
                a

            {}
        )
        Object.freeze ret

    else
        args.reduce (a,b) -> a + b

filter_dict = (d, filter_fn) ->
    ret = {}
    for own k, v of d
        ret[k] = v if filter_fn k, v

    Object.freeze ret

is_debug_context = (argv_or_ctx) ->
    if argv_or_ctx.hasOwnProperty 'full_args'
        argv_or_ctx.full_args.global.hasOwnProperty 'debug'
    else
        argv_or_ctx.global.hasOwnProperty 'debug'

read_json_file = (filename) ->
    if fs.existsSync filename
        try
            Object.freeze(JSON.parse(fs.readFileSync(filename, FILE_ENCODING)))
        catch e
            scream "Error reading #{filename}: #{e}"
            whisper "#{e.stack}"
            undefined
    else
        undefined

read_json_file.async = (filename, cb) ->
    fs.readFile filename, FILE_ENCODING, (err, res) ->
        if err
            scream "Error reading file #{filename}"
            cb err
        else
            try
                cb CB_SUCCESS, (Object.freeze (JSON.parse res))
            catch e
                scream "Error parsing json file #{filename}: #{e}"
                whisper "#{e.stack}"
                cb e


trim = (s) -> s.replace /^\s+|\s+$/g, ''

exists = (fn) ->
    fs.existsSync fn

exists.async = (fn, cb) ->
    fs.exists fn, (exs) -> cb CB_SUCCESS, exs

is_dir = (fn) ->
    if exists fn
        stat = fs.lstatSync fn
        stat.isDirectory()
    else
        false

is_dir.async = (fn, cb) ->
    fs.lstat fn, (err, stat) ->
        if err
            cb err, false
        else
            cb CB_SUCCESS, stat.isDirectory()

is_file = (fn) ->
    if exists fn
        !is_dir fn
    else
        false

is_file.async = (fn, cb) ->
    fs.lstat fn, (err, stat) ->
        if err
            cb err, false
        else
            cb CB_SUCCESS, stat.isFile()


has_ext = (fn, ext) ->
    re = new RegExp "\\.#{ext}$", 'i'
    !!fn.match re

has_ext.async = (fn, ext, cb) ->
    cb CB_SUCCESS, (has_ext fn, ext)

get_plugins = (base_dir) ->
    (file.replace JS_PATTERN, '' for file in fs.readdirSync base_dir \
                                  when JS_PATTERN.test file)

is_object = (v) ->
    try
        if v.toString() is '[object Object]' then true else false
    catch e
        false

extend = (a, b) ->
    unless (is_object a) and (is_object b)
        throw "Arguments type mismatch: #{a}, #{b}"

    ret = {}
    for k,v of a
        ret[k] = v

    for k, v of b
        ret[k] = if ret[k] and is_object ret[k]
            extend a[k], v
        else
            v
    ret

newer = (a, b) ->
    try
        (get_mtime a) > (get_mtime b)
    catch e
        true

build_update_reenter_cmd = (ctx) ->
    arg1 = (arg) -> "-#{arg}"
    arg2 = (arg, val) -> "--#{arg}#{if val is undefined then '' else '=' + val}"
    format_arg = (arg, val) -> if val is true then arg1(arg) else arg2(arg, val)

    # we don't want logo to be printed the second time
    cmd_args = ['--nologo']

    # adding global arguments before all commands
    cmd_args.push(format_arg(arg, val)) for arg, val of ctx.global when arg isnt 'update'

    # adding commands and their arguments
    for command, args of filter_dict(ctx, (k, v) -> k isnt 'global')
        cmd_args.push "#{command}"
        cmd_args.push(format_arg(arg, val)) for arg, val of args

    cmd_args

reenter = (ctx, cb) ->
    cmd_args = build_update_reenter_cmd ctx

    run = spawn process.argv[1], cmd_args

    run.stdout.on 'data', (data) -> say "#{data}".replace /\n$/, ''
    run.stderr.on 'data', (data) -> scream "#{data}".replace /\n$/, ''
    run.on 'exit', (code) ->
        shout "=== Re-enter finished with code #{code} ==========="
        cb? 'stop'

get_opt = (opt, bundle_opts, recipe_opts) ->
    switch bundle_opts?[opt]
        when true then true
        when false then false
        else !!recipe_opts?[opt]

get_result_filename = (source_fn, target_fn, src_ext, dst_ext) ->
    """
    Creates destination file name for compiled file(if exists).
    else return passed target_fn.
    Parameters:
        @source_fn : path to source file.
        @target_fn : destination path for compiled result.
        @src_ext : extension of source file.
        @dst_ext : extension for destination file.
    """

    if is_dir target_fn
        name = ((path.basename source_fn).replace((new RegExp "#{src_ext}$"), '')) + dst_ext
        path.resolve target_fn, name
    else
	    target_fn

and_ = (args...) -> args.reduce (a, b) -> !!a and !!b

or_ = (args...) -> args.reduce (a, b) -> !!a or !!b

get_all_relative_files = (filepath, exclude_pattern=null, include_pattern=null) ->
    """
    Gets all filenames recursively relative to filepath.
    @filepath: dir path
    @exclude_pattern: regexp for exclude files patterns
    @include_pattern: regexp for include files patterns
    """

    return [filepath] unless (is_dir filepath)

    is_match = (fn) ->
        include = if include_pattern then include_pattern.test(fn) else true
        exclude = if exclude_pattern then !exclude_pattern.test(fn) else true
        include and exclude

    files = []

    next = (dir) ->
        for file in fs.readdirSync(dir)
            file = "#{dir}/#{file}"
            files.push file if (is_match file)
            next(file) if (is_dir file)

    next filepath

    files

module.exports = {
    read_slug
    walk
    flatten
    toArray
    mtime_to_unixtime
    get_mtime
    newest
    maybe_build
    camelize
    expandPath
    add
    filter_dict
    is_debug_context
    read_json_file
    trim
    exists
    is_dir
    is_file
    has_ext
    get_plugins
    is_object
    extend
    newer
    is_array
    reenter
    get_opt
    get_result_filename
    get_all_relative_files
    and_
    or_
}
