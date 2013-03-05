# TODO: write documentation header.

fs = require 'fs'
path = require 'path'
uglify = require 'uglify-js'
async = require 'async'
{get_mtime, is_file, is_dir, walk} = require './utils'
{say, shout, scream, whisper} = (require './logger') "Minify>"

{FILE_ENCODING, MINIFY_INCLUDE_PATTERN,
 MINIFY_EXCLUDE_PATTERN, MINIFY_MIN_SUFFIX} = require '../defs'

EVENT_MINIFY_DONE = "MINIFY_DONE"


class Minifier
    constructor: (ctx) ->
        @src_dir = ctx.own_args.src
        @dst_dir = ctx.own_args.dst
        @fn_pattern = ctx.own_args.pattern
        @emitter = ctx.emitter
        @fb = ctx.fb
          # body...

    minify: (cb, force) =>
        do_it = (err, results) =>
            if err
                cb 'fs_error', err

            else
                routines = ((@_get_minificator f, @dst_dir, @fn_pattern, force) for f in results)
                runner = (fun, cb) -> fun cb
                done = (err, res) -> cb err, res

                async.map routines, runner, done
        
        if is_file @src_dir
            do_it null, [@src_dir]
        else
            walk @src_dir, do_it

    _get_minificator: (file, dst_dir, fn_pattern, force) ->
        (cb) =>
            full_filename = path.resolve file
            dirname = dst_dir or path.dirname full_filename
            basename = path.basename full_filename

            if (MINIFY_INCLUDE_PATTERN.test basename) and not (MINIFY_EXCLUDE_PATTERN.test basename)

                if fn_pattern and not basename.match fn_pattern
                    return cb()

                min_filename = basename.replace MINIFY_INCLUDE_PATTERN, MINIFY_MIN_SUFFIX
                min_full_filename = path.resolve dirname, min_filename

                unless force
                    unless @_maybe_minify full_filename, min_full_filename
                        @emitter.emit "MINIFY_SKIP"
                        @fb.shout "#{min_full_filename} still hot"
                        return cb()

                fs.readFile(full_filename, FILE_ENCODING, (err, data) =>
                    if err
                        @fb.shout "Error reading file '#{full_filename}': #{err}"
                        scream "Error reading file '#{full_filename}': #{err}"

                        cb()
                    else
                        fs.writeFile(min_full_filename, (uglify.minify data, {fromString: true}), FILE_ENCODING, (err) =>
                            if err
                                @fb.shout "Error writing file '#{min_full_filename}': #{err}"
                                scream "Error writing file '#{min_full_filename}': #{err}"

                                cb()
                            else
                                @fb.say "#{min_full_filename} written"
                                @emitter.emit EVENT_MINIFY_DONE

                                cb()
                        )
                )
            else
                cb()

    _maybe_minify: (file, min_file) ->
        try
            (get_mtime file) >= (get_mtime min_file)
        catch ex
            true


module.exports = Minifier
