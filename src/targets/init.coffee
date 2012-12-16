help = [
    """
    Initializes new client side application skelethon.

    Parameters:
      - app_root - [optional, default - 'cs'] - client side application root (where your modules will be stored).
                    Will be created if not exists, or just add recipe json to existing 
                    folder.

      - build_root - [optional, default - 'public'] - 
                      folder for storing processed js bundles. Will be created if not exists.

    Creates menu file with commands:
      - build   - simple application build
      - fbuild  - force build
      - wbuild  - build and watch application files.

    """
]

fs = require 'fs'
path = require 'path'
{is_dir, is_file, exists} = require '../lib/utils'
recipe_etalon_path = path.resolve __dirname, '../../assets/templates/init/recipe/recipe.json'
{make_target} = require '../lib/target'
{make_skelethon} = require '../lib/skelethon/skelethon'
menu = require '../lib/menu'
mkdirp = require 'mkdirp'
async = require 'async'

DEFAULT_APP_ROOT = 'cs'
DEFAULT_BUILD_ROOT = 'public'



app_init = (ctx, cb) ->
    ctx.fb.say 'Initializing new client side app'
    {app_root, build_root} = ctx.own_args

    app_root or= DEFAULT_APP_ROOT
    build_root or=DEFAULT_BUILD_ROOT

    # app_root 
    create_app_root = (cb) ->
        unless exists app_root
            mkdirp app_root, (err) ->
                ctx.fb.say "Created app_root - #{app_root}."
                cb()
        else
            ctx.fb.shout "app_root #{app_root} exists. Skip creating"
            cb()

    # build root
    create_build_root = (cb) ->
        # recipe.json
        create_recipe_json = () ->
            recipe = fs.readFileSync recipe_etalon_path
            fs.writeFileSync (path.join app_root, 'recipe.json'), recipe
            ctx.fb.say "#{app_root}/recipe.json file created"
            cb()

        unless exists build_root
            mkdirp build_root, (err) ->
                ctx.fb.say "Created build_root - #{build_root}."
                create_recipe_json()

        else
            ctx.fb.shout "build_root #{build_root} exists. Skip creating"
            create_recipe_json()


    create_menu_file = (cb) ->
        build = 
            build:
                app_root: app_root
                build_root: build_root
                formula: 'recipe.json'

        fbuild = 
            build:
                app_root: app_root
                build_root: build_root
                formula: 'recipe.json'
                f: true 

        wbuild = 
            build:
                app_root: app_root
                build_root: build_root
                formula: 'recipe.json'
            watch:
                src: app_root

        menu._do_new_menu 'build', {full_args: build, fb: ctx.fb}
        menu._do_new_menu 'fbuild', {full_args: fbuild, fb: ctx.fb}
        menu._do_new_menu 'wbuild', {full_args: wbuild, fb: ctx.fb}

        cb()

    async.parallel [
        create_app_root
        create_build_root
        create_menu_file
        ], (err, results) ->
            cb 'stop'

module.exports = make_target "init", app_init, help
