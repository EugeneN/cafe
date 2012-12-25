p = require 'path'

make_compiler = (compilers)->
    compilers or= []

    validate_compiler = (compiler) ->
        (compiler.hasOwnProperty 'ext') and (compiler.hasOwnProperty 'compile')


    for c in compilers
        throw "Copmiler #{c} has wrong interface" unless (validate_compiler c)

    register_compiler_by_path: (path) ->
        """
        Registers compiler by filename.
        """

        compiler = require path
        if validate_compiler compiler
            compilers.push compiler
        else
            throw "Compiler from path #{path} must implement methods 'match' and 'compile'"


    register_compiler: (compiler) ->
        if validate_compiler compiler
            compilers.push compiler
        else
            throw "Compiler #{compiler} must implement methods 'match' and 'compile'"


    compile: (paths) ->
        """
        @paths: list of paths for compilation.
        Returns:
            {path, source}
        """

        get_compiler = (path, compilers) ->
            for c in compilers
                return c if c.ext is  (p.extname path)[1..]

            throw "No compiler is registered for path #{path}" # TODO: link to instruction for cafe compiler registration.

        paths.map((p) ->
            try
                {path:p, source: (get_compiler(p, compilers).compile p)}
            catch e
                throw "Failed to compile file #{p}. #{e}"
        )

module.exports = make_compiler
