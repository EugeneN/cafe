# Spine modules compiller.
# TODO: write documentation headers.

fs        = require 'fs'
path      = require 'path'
_package   = require './stitch'
exec = require('child_process').exec

{add, is_file, read_slug} = require './utils'
{say, shout, scream, whisper} = (require './logger') "CSMCompiler>"

{SLUG_FN} = require '../defs'

class SM_Compiler
    ###
    Spine module compiler.
    ###

    constructor: (@base_path, @ctx, options = {}) ->
        @emitter = @ctx.emitter
        @fb = @ctx.fb

        options.slug = @_abs_path SLUG_FN

        slug_options = @readSlug options.slug

        @options = add slug_options, options

    readSlug: (slug) ->
        if is_file slug
            json_slug = read_slug path.dirname slug

            scream slug, json_slug

            json_slug.paths = json_slug.paths.map @_abs_path
            json_slug.public = @_abs_path json_slug.public
            json_slug.fileTests = @_abs_path json_slug.fileTests
            json_slug.folderTests =@_abs_path json_slug.folderTests
            # TODO: handle other arguments paths overriding.

            json_slug
        else
            {}


    _abs_path: (rel) =>
        path.resolve(path.join(@base_path, rel)) if rel


    _get_js_path: ->
        path.join @options.public, @options.jsPath


    _write_file: (filename, source, cb) =>
        fs.writeFile filename, source, (err) =>
            if err
                throw err
            else
                cb()

    build: (cb) ->
        try
            source = @module().compile (err, source) =>
                js_path = @_get_js_path()

                @_write_file js_path, source, =>
                    @fb.say "#{js_path} brewed."
                    @emitter.emit "COMPILE_DONE"
                    cb? null, js_path

        catch error
            @fb.scream "Failed to build #{@base_path} #{error}"
            @fb.whisper "#{error.stack}"
            scream "Failed to build #{@base_path} #{error}"
            whisper "#{error.stack}"

            @emitter.emit "COMPILE_FAIL"
            cb? 'target_error'


    build_tests: (cb) ->
        # FIXME resolve this at runtime
        # or maybe import coffe-script and compile in-place?
        COFFEE = '/usr/bin/coffee'

        unless @options.fileTests? or @options.folderTests?
            @fb.shout "Test folder is not set #{@base_path}"
            @emitter.emit "COMPILE_TESTS_SKIP"
            cb?()
            return

        filename = @options.fileTests
        folder_tests = @options.folderTests

        if filename
            cmd = "#{COFFEE} -c -o #{folder_tests} #{filename}"
            cwd = @base_path

            exec cmd, {cwd}, (err, stdout, stderr) =>
                if err
                    @fb.scream "Build failed for tests: #{err}"
                    cb?()
                    @emitter.emit "COMPILE_TESTS_FAIL"

                else
                    @fb.say "Tests built for #{filename}"
                    cb?()
                    @emitter.emit "COMPILE_TESTS_DONE"
        else
            @fb.scream "File with the tests could not be found"
            cb?()

    module: ->
        _package.createPackage
            dependencies: @options.dependencies
            paths: @options.paths
            libs: @options.libs


module.exports = SM_Compiler
