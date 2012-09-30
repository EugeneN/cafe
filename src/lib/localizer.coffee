path = require 'path'
fs = require 'fs'
optimist = require 'optimist'
async = require 'async'
Gettext = require './gettext'
{say, shout, scream} = require('./logger') "Localizer>"
{is_dir} = require './utils'

NEW_LINE = '\n'
PO_FILE_SUFFIX = 'LC_MESSAGES'
PO_FILE_NAME = 'uaprom.po'

EXCLUDE_PATTERN = /\-min\.js$/i
INCLUDE_PATTERN = /\.js$/i

LOG_PREFIX = 'LOCA>'

help = ->
    optimist.showHelp()
    process.exit(3)


get_available_locales = (root_dir) ->
    (fn for fn in fs.readdirSync(root_dir) when is_dir(path.join(root_dir, fn)))


get_writer = (filename_to_translate, cb) ->
    (locale, data) ->
        base_dir = path.dirname filename_to_translate
        base_name = path.basename filename_to_translate
        new_base_dir = path.join base_dir, locale
        new_filename = path.join(new_base_dir, base_name)

        write_file = ->
            fs.writeFile new_filename, data, (err) ->
                shout "Error writing file #{new_filename}: #{err}" if err
                say "Writing localized file #{new_filename}"
                cb?()

        if is_dir(new_base_dir)
            write_file()
        else
            fs.mkdir new_base_dir, '0755', (err) ->
                if err
                    shout "Error creating directory #{new_base_dir}: #{err}"
                else
                    write_file()


localize_file = (filename_to_translate, locale, gettext, cb) ->
    translate_line = (line) ->
        _replacer = (fun) ->
            (m...) ->
                quote = m[2]
                text = gettext[fun](m[3])

                text = text.replace(quote, '\\' + quote)
                quote + text + quote

        line = line.replace /\b(_\(\s*?(['"])(.*?)['"]\s*?\))/g, _replacer('gettext')
        line = line.replace /\b(gettext\(\s*?(['"])(.*?)['"]\s*?\))/g, _replacer('gettext')

    fs.readFile filename_to_translate, 'utf-8', (err, data) ->
        if err
            shout "Error reading file #{filename_to_translate}: #{err}"
        else
            get_writer(filename_to_translate, cb)(
                locale,
                (translate_line(line) for line in data.split(NEW_LINE)).join(NEW_LINE))


translate_dir_to_locale = (dir, locale, gettext, cb) ->
    fs.readdir dir, (err, list) ->
        if err
            shout "Error reading directory #{dir}: #{err}"

        else if list.length
            list.map (filename) ->
                translate_fn_to_locale(dir, filename, locale, gettext)


translate_fn_to_locale = (filename, locale, gettext, cb) ->
    if filename.match(INCLUDE_PATTERN) and not filename.match(EXCLUDE_PATTERN)

        fs.stat filename, (err, stat) ->
            if err
                shout "Error getting stat on " +
                            "#{filename}: #{err}"
            else
                unless stat?.isDirectory()
                    localize_file filename, locale, gettext, cb
    else
        cb?()


_go_after_locale_factory = (locale, po_file_name, filename) ->
    (cb) ->
        gettext = new Gettext(locale)
        gettext.loadLanguageFile po_file_name, ->
            translate_fn_to_locale(filename, locale, gettext, cb)


_localization_cycle = (locales_root_dir, filename) ->
    (cb) ->
        seq = []
        for locale in get_available_locales locales_root_dir
            po_file_name = path.join locales_root_dir, locale, PO_FILE_SUFFIX, PO_FILE_NAME
            seq.push _go_after_locale_factory locale, po_file_name, filename

        async.series seq, ->
            cb?()


_get_files = (dir) ->
    (path.join(dir, file) for file in fs.readdirSync(dir) \
        when fs.statSync(path.join(dir, file)).isFile())


localize_run = (locales_root_dir, filename, cb) ->
    say "Running localization for #{filename}"
    dir = fs.lstatSync(filename).isDirectory()
    seq = []
    
    console.log 'files', _get_files(filename)

    unless dir
        seq.push _localization_cycle(locales_root_dir, filename)
    else
        seq.push _localization_cycle(locales_root_dir, f) for f in _get_files(filename)

    async.series seq, ->
        say "Localization is done"
        cb?()


module.exports = {localize_run}
