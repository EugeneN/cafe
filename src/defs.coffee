fs = require 'fs'
path = require 'path'
{extend} = require './lib/utils'

CONFIG_FILE = path.resolve process.env.HOME, '.cafe.json'

read_json_file = (filename) ->
    if fs.existsSync filename
        try
            Object.freeze(JSON.parse(fs.readFileSync(filename, 'utf-8')))
        catch e
            console.error "Can't read #{CONFIG_FILE}: #{e}"
    else
        {}

user_config = read_json_file CONFIG_FILE

VERSION_FILE = 'package.json'
CAFE_TARBALL = 'cafe.tar.gz'

VERSION_FILE_PATH = path.resolve __dirname, "..", VERSION_FILE

VERSION = do ->
    try
        (JSON.parse fs.readFileSync(VERSION_FILE_PATH).toString()).version
    catch e
        undefined

TMP_BUILD_DIR_SUFFIX = 'build' # remove this
BUILD_DIR = 'build'

TARGET_PATH = path.resolve __dirname, './targets/'
ADAPTERS_PATH = path.resolve __dirname, "./adapters"
ADAPTERS_LIB = path.resolve __dirname, "./adapters"
ADAPTER_FN = 'adapter'
SKELETHON_ASSETS_PATH = path.resolve __dirname, "../assets/adapters/"
SKELETHON_FN = 'skelethon'

SUB_CAFE = path.resolve __dirname, '../bin/cafe'


default_config =
    VERSION: VERSION
    VERSION_FILE_PATH: VERSION_FILE_PATH

    SLUG_FN: 'slug.json'

    FILE_ENCODING: 'utf-8'

    TMP_BUILD_DIR_SUFFIX: TMP_BUILD_DIR_SUFFIX
    CS_ADAPTOR_PATH_SUFFIX: 'domain/'

    CS_EXT: '.coffee'
    JS_EXT: '.js'
    BUILD_FILE_EXT: '.js'
    COFFEE_PATTERN: /\.coffee$/
    JS_PATTERN: /\.js$/

    MINIFY_MIN_SUFFIX: '-min.js'
    MINIFY_EXCLUDE_PATTERN: /\-min\.js$/i
    MINIFY_INCLUDE_PATTERN: /\.js$/i

    EOL: '\n'
    BUNDLE_HDR: "/* Cafe #{VERSION} #{new Date} */\n"
    BUNDLE_ITEM_HDR: (file_path) -> "/* ZB:#{path.basename file_path} */\n"
    BUNDLE_ITEM_FTR: ';\n'

    TARGET_PATH: TARGET_PATH
    ADAPTERS_PATH: ADAPTERS_PATH
    ADAPTER_FN: ADAPTER_FN
    SKELETHON_FN: SKELETHON_FN
    ADAPTERS_LIB: ADAPTERS_LIB
    BUILD_DIR: BUILD_DIR

    WATCH_FN_PATTERN: /^[^\.].+\.coffee$|^[^\.].+\.yaml$|^[^\.].+\.jison$|^[^\.].+\.json$|^[^\.].+\.eco|^[^\.].+\.js$|^[^\.].+\.cljs$/i
    WATCH_IGNORE: /^\.+|^[^\.].+\.cache$/

    RECIPE_EXT: '.json'
    RECIPE: "recipe.json"
    BUILD_DEPS_FN: 'build_deps.json'
    RECIPE_API_LEVEL: 5

    MENU_FILENAME: './Menufile'

    CLEANUP_CMD: 'sudo npm remove -g cafe'
    UPDATE_CMD: 'sudo npm update -g cafe4'

    EVENT_CAFE_DONE: 'CAFE_DONE'
    EVENT_BUNDLE_CREATED: 'CAFE.BUNDLE.CREATED'

    EXIT_SUCCESS: 0
    EXIT_TARGET_ERROR: 1
    EXIT_OTHER_ERROR: 2
    EXIT_HELP: 3
    EXIT_SIGINT: 4
    EXIT_NO_STATUS_CODE: 5
    EXIT_SIGTERM: 6
    EXIT_PARTIAL_SUCCESS: 7
    EXIT_VERSION_MISMATCH: 8

    SIGTERM: 15
    SIGINT: 2
    PR_SET_PDEATHSIG: 1

    TELNET_UI_HOST: '0.0.0.0'
    TELNET_UI_PORT: 8888

    SUB_CAFE: SUB_CAFE

    LISPY_BIN: 'lispy'
    LISPY_EXT: 'lspy'

    CLOJURESCRIPT_BIN: 'cljsc'
    CLOJURESCRIPT_EXT: 'cljs'

    LEIN_BIN: 'lein'
    LEIN_ARGS: 'cljsbuild once'
    PROJECT_CLJ: 'project.clj'

    LIVESCRIPT_BIN: 'livescript'
    LIVESCRIPT_EXT: 'ls'

    COFFEESCRIPT_EXT: 'coffee'

    CAKE_BIN: '/usr/bin/cake'
    CAKEFILE: 'Cakefile'
    CAKE_TARGET: 'cafebuild'
    CAFE_TMP_BUILD_ROOT_ENV_NAME: 'CAFE_TMP_BUILD_ROOT'
    CAFE_TARGET_FN_ENV_NAME: 'CAFE_TARGET_FN'

    NODE_PATH: process.env.NODE_PATH

    TELNET_CMD_MARKER: 0xff
    IAC_WILL_ECHO: [0xff,0xfb,0x1]
    IAC_WONT_ECHO: [0xff,0xfc,0x1]

    FILE_TYPE_COMMONJS: 'commonjs'
    FILE_TYPE_PLAINJS: 'plainjs'

    CB_SUCCESS: null

    UI_CMD_PREFIX: '/'

    CS_RUN_CONCURRENT: true

    CLOJURESCRIPT_OPTS: '{:optimizations :simple :pretty-print true}'
    JS_JUST_EXT: 'js'

    THRESHOLD_INTERVAL: 3000 # ms

    DEFAULT_CS_DIR : 'csapp'
    DEFAULT_CS_BUILD_DIR : 'build'
    SUCCESS_ICO : path.resolve __dirname, '../assets/img/success.jpg'
    FAILURE_ICO : path.resolve __dirname, '../assets/img/failure.jpg'
    SKELETHON_ASSETS_PATH: SKELETHON_ASSETS_PATH
    CAFE_DIR: '.cafe'
    NPM_MODULES_PATH: 'node_modules'

module.exports = extend default_config, user_config
