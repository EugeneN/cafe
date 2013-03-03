help = [
    """
    Reads a recipe and build an application according to the recipe.
    Resolves dependencies (up to 5 lvls deep), compiles them using appropriate
    adapters, generates build deps spec for use outside of the applications.

    Parameters:
    - app_root    - directory with client-side sources

    - build_root  - directory to put built code into

    - formula     - formula to use for each particular build,
    'recipe.json' by default

    There may be 3 types of dependencies in recipe.json
    and in `recipe` array in slug.json files

    1. CoffeeScript modules
    2. JavaScript group (i.e. `jquery` is a group that includes
    jquery itself but also jquery-ui and jquery.cookie)
    3. JavaScript file

    1) CoffeeScript modules are specified by names. Appropriate adapter will look
    for the respective location on th filesystem.

    (2) JavaScript groups are described in recipe.json in `deps`. Path specifications
    must match those of (3).

    Example (in recipe.json):
    "deps":{
    "utils": [
    "shopping_cart.js",
    "uaprom_common.js",
    "utils.js"
    ]
    },

    (3) JavaScript files must be specified by a path relative to
    the recipe.json location.

    Example:
    "baselib/uaprom.js",                // <- file in build_root
    "baselib/jquery/jquery-1.6.2.js",   // <- file in subdir jquery of build_root

    Each particular adaptor may use it's own algorythms for dependencies resolving
    and filesystem lookup.
    """
]


{make_target} = require '../lib/target'
{run_build_sequence} = require '../lib/build/build_sequence'
{is_dir} = require '../lib/utils'
{CB_SUCCESS} = require '../defs'

check_ctx = (ctx, cb) ->
    unless ctx.own_args.app_root and ctx.own_args.build_root
        cb ["app_root and/or build_root arguments missing", 'bad_ctx']

    else unless is_dir ctx.own_args.app_root
        cb ["App root #{ctx.own_args.app_root} is not a directory", 'bad_ctx']

    else
        cb CB_SUCCESS, true


build = (ctx, cb) ->
    check_ctx ctx, (err, valid) ->
        if err
            cb err
        else
            run_build_sequence ctx, cb


module.exports = make_target "build", build, help
