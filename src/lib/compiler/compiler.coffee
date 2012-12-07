p = require 'path'

make_compiler = (compilers)->
    compilers or= []

    validate_compiler: (compiler) ->
        [
            (compiler.hasOwnProperty 'ext')
            (compiler.hasOwnProperty 'compile')

        ].reduce(a, b) -> a and b


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
                return c if c.ext is  (p.exname path)[1..]

            throw "No compiler is registered for path #{p}" # TODO: link to instruction for cafe compiler registration.

        paths.map((p) -> {path:p, source: (get_compiler(p, compilers).compile p)})

module.exports = make_compiler
