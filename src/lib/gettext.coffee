fs = require "fs"
path = require "path"


CONTEXT_GLUE = '\\004'
DEFAULT_DOMAIN = 'messages'


is_valid_object = (o) ->
    if o is null
        false
    else if o is undefined
        false
    else
        true

is_empty_object = (o) -> (i for own i of o).length is 0

parse_po_dequote = (str) ->
    match = str.match /^"(.*)"/
    if match
        str = match[1]

    str.replace(/\\"/g, "\"")

is_array = (o) -> is_valid_object o and o.constructor is Array

trim = (s) -> s.replace(/^\s*/, '').replace(/\s*$/, '')

say = (a...) -> console.log.apply({}, a)

parse_po = (data) ->
    rv = {}
    buffer = {}
    lastbuffer = ""
    errors = []
    lines = data.split "\n"

    for line in lines
        line = line.replace /(\n|\r)+$/, ''

        if /^$/.test(line)
            if buffer.msgid
                msg_ctxt_id = if buffer.msgctxt?.length
                    buffer.msgctxt + CONTEXT_GLUE + buffer.msgid
                else
                    buffer.msgid

                msgid_plural = if buffer.msgid_plural?.length
                    buffer.msgid_plural
                else
                    null

                trans = []
                for str of buffer
                    match = str.match /^msgstr_(\d+)/
                    if match
                        trans[parseInt(match[1], 10)] = buffer[str]

                trans.unshift msgid_plural

                if trans.length > 1
                    rv[msg_ctxt_id] = trans

                buffer = {}
                lastbuffer = ""

        # comments
        else if /^#/.test(line)

        # msgctxt
        else if (match = line.match(/^msgctxt\s+(.*)/))
            lastbuffer = 'msgctxt'
            buffer[lastbuffer] = parse_po_dequote(match[1])

        # msgid
        else if (match = line.match(/^msgid\s+(.*)/))
            lastbuffer = 'msgid'
            buffer[lastbuffer] = parse_po_dequote(match[1])

        # msgid_plural
        else if (match = line.match(/^msgid_plural\s+(.*)/))
            lastbuffer = 'msgid_plural'
            buffer[lastbuffer] = parse_po_dequote(match[1])

        # msgstr
        else if (match = line.match(/^msgstr\s+(.*)/))
            lastbuffer = 'msgstr_0'
            buffer[lastbuffer] = parse_po_dequote(match[1])

        # msgstr[0] (treak like msgstr)
        else if (match = line.match(/^msgstr\[0\]\s+(.*)/))
            lastbuffer = 'msgstr_0'
            buffer[lastbuffer] = parse_po_dequote(match[1])

        # msgstr[n]
        else if (match = line.match(/^msgstr\[(\d+)\]\s+(.*)/))
            lastbuffer = 'msgstr_'+match[1]
            buffer[lastbuffer] = parse_po_dequote(match[2])

        # continued string
        else if /^"/.test(line)
            buffer[lastbuffer] += parse_po_dequote(line)

        # something strange
        else
            errors.push("Strange line [#{i}] : #{line}")


    if buffer.msgid isnt undefined
        msg_ctxt_id = if buffer.msgctxt?.length
            buffer.msgctxt + CONTEXT_GLUE + buffer.msgid
        else
            buffer.msgid

        msgid_plural = if buffer.msgid_plural?.length
            buffer.msgid_plural
        else
            null


        trans = []
        for str of buffer
            if (match = str.match(/^msgstr_(\d+)/))
                trans[parseInt(match[1], 10)] = buffer[str]

        trans.unshift(msgid_plural)

        if trans.length > 1
            rv[msg_ctxt_id] = trans

        buffer = {}
        lastbuffer = ""

    if rv[""] and rv[""][1]
        cur = {}
        hlines = rv[""][1].split(/\\n/)

        for hl in hlines
            pos = hl.indexOf(':', 0)

            if pos isnt -1
                keylow = hl.substring(0, pos).toLowerCase()
                val = hl.substring(pos + 1)

                if cur[keylow] and cur[keylow].length
                    errors.push "SKIPPING DUPLICATE HEADER LINE: " + hl

                else if /#-#-#-#-#/.test(keylow)
                    errors.push "SKIPPING ERROR MARKER IN HEADER: " + hl

                else
                    val = val.replace /^\s+/, ''
                    cur[keylow] = val

            else
                errors.push "PROBLEM LINE IN HEADER: " + hl
                cur[hl] = ''

        rv[""] = cur

    else
        rv[""] = {}

    rv


class Gettext
    constructor: (locale) ->
        @LOCALE = locale
        @LOCALE_DATA = {}

    parse_locale_data: (locale_data, locale) ->
        L = @LOCALE_DATA

        L[locale] = {} unless L[locale]

        for own domain, data of locale_data
            if is_valid_object(data) and not is_empty_object(data)
                domain or= DEFAULT_DOMAIN

                unless is_valid_object(L[locale][domain])
                    L[locale][domain] = {}

                unless is_valid_object(L[locale][domain].head)
                    L[locale][domain].head = {}

                unless is_valid_object(L[locale][domain].msgs)
                    L[locale][domain].msgs = {}

                for own key, val of data
                    if key is ''
                        header = val
                        for own head, header_val of header
                            L[locale][domain].head[head.toLowerCase()] = header_val
                    else
                        L[locale][domain].msgs[key] = val

        # build the plural forms function

        for domain of L[locale]
            _head = L[locale][domain].head

            if is_valid_object(_head['plural-forms']) and _head.plural_func is undefined
                _parse_pf = (pf_str) ->
                    [a1, a2] = (trim(i) for i in pf_str.split(';'))

                    [_, nplurals] = (trim(i) for i in a1.split('='))
                    plural_expr = (trim(a2)).replace(/\s*/g, '').replace(/plural=/, '')

                    [nplurals, plural_expr]

                [nplurals, plural_expr] = _parse_pf _head['plural-forms']

                if nplurals and plural_expr
                    _x = (nplurals, plural_expr) ->
                        (n) ->
                            {
                                nplural: nplurals,
                                plural: eval(plural_expr) # XXX !!!
                            }

                    _head.plural_func = _x(nplurals, plural_expr)

                else
                    throw "Syntax error in language file. " +
                        "Plural-Forms header is invalid ['#{plural_forms}']"

            else if _head.plural_func is undefined
                _head.plural_func = (n) ->
                    {
                        nplural: 2,
                        plural: if n isnt 1 then 1 else 0
                    }

    loadLanguageFile: (file, callback) ->
        return unless file

        locale = @LOCALE
        unless  locale
            throw "Locale not set"

        domain = path.basename(file, '.po')

        fs.readFile(file, 'utf8', (err, data) =>
            throw err if err

            parsed = parse_po(data)
            rv = {}

            # munge domain into/outof header
            if parsed
                parsed[""] = {} unless parsed[""]
                parsed[""].domain = domain unless parsed[""].domain

                domain = parsed[""].domain
                rv[domain] = parsed

                @parse_locale_data(rv, locale)

            callback?()
        )

    # loads all po files from a flat locale directory tree.
    # -> LANGUAGE_NAME/domain.po
    # eg. en/jsgettext.po de/jsgettext.po etc.
    loadLocaleDirectory: (directory, callback) ->
        self = this

        fs.readdir(directory, (err, files) ->
            pendingDirectories = files.length

            unless pendingDirectories
                return callback?()

            files.forEach((file) ->
                file = path.join directory, file

                fs.stat(file, (err, stats) ->
                    if not err and stats.isDirectory()
                        l = file.match(/[^\/]+$/)[0]

                        fs.readdir(file, (err, files) ->
                            pendingFiles = files.length

                            unless pendingFiles
                                unless !--pendingDirectories
                                    return callback?()

                            files.forEach((file) ->
                                file = path.join directory, l, file

                                if path.extname(file) is '.po'
                                    fs.stat(file, (err, stats) ->
                                        if not err and stats.isFile()
                                            self.loadLanguageFile(file, l, () ->
                                                unless --pendingFiles
                                                    unless --pendingDirectories
                                                        return callback?()
                                            )

                                        else
                                            unless --pendingFiles
                                                unless --pendingDirectories
                                                    return callback?()
                                    )

                                else
                                    unless --pendingFiles
                                        unless --pendingDirectories
                                            return callback?()
                            )
                        )

                    else
                        console.log(file)
                        unless --pendingDirectories
                            return callback?()

                )
            )
        )

    setlocale: (category, locale) ->
        # ignore category for now
        category = 'LC_ALL'
        @LOCALE = locale

    textdomain: (d) ->
        if d?.length then d else undefined

    # gettext
    gettext: (msgid) ->
        @dcnpgettext(null, undefined, msgid, undefined, undefined, undefined)

    dgettext: (domain, msgid) ->
        @dcnpgettext(domain, undefined, msgid, undefined, undefined, undefined)

    dcgettext: (domain, msgid, category) ->
        @dcnpgettext(domain, undefined, msgid, undefined, undefined, category)

    # ngettext
    ngettext: (msgid, msgid_plural, n) ->
        @dcnpgettext(null, undefined, msgid, msgid_plural, n, undefined)

    dngettext: (domain, msgid, msgid_plural, n) ->
        @dcnpgettext(domain, undefined, msgid, msgid_plural, n, undefined)

    dcngettext: (domain, msgid, msgid_plural, n, category) ->
        @dcnpgettext(domain, undefined, msgid, msgid_plural, n, category, category)

    # pgettext
    pgettext: (msgctxt, msgid) ->
        @dcnpgettext(null, msgctxt, msgid, undefined, undefined, undefined)

    dpgettext: (domain, msgctxt, msgid) ->
        @dcnpgettext(domain, msgctxt, msgid, undefined, undefined, undefined)

    dcpgettext: (domain, msgctxt, msgid, category) ->
        @dcnpgettext(domain, msgctxt, msgid, undefined, undefined, category)

    # npgettext
    npgettext: (msgctxt, msgid, msgid_plural, n) ->
        @dcnpgettext(null, msgctxt, msgid, msgid_plural, n, undefined)

    dnpgettext: (domain, msgctxt, msgid, msgid_plural, n) ->
        @dcnpgettext(domain, msgctxt, msgid, msgid_plural, n, undefined)

    # this has all the options, so we use it for all of them.
    dcnpgettext: (domain, msgctxt, msgid, msgid_plural, n, category) ->
        return '' unless is_valid_object(msgid)

        plural = is_valid_object(msgid_plural)

        msg_ctxt_id = if is_valid_object(msgctxt)
            msgctxt + CONTEXT_GLUE + msgid
        else
            msgid

        domainname = if is_valid_object(domain)
            domain
        else
            DEFAULT_DOMAIN

        # category is always LC_MESSAGES. We ignore everything else
        category_name = 'LC_MESSAGES'
        category = 5

        locale_data = []
        if is_valid_object(@LOCALE_DATA[@LOCALE]?[domainname])
            locale_data.push(@LOCALE_DATA[@LOCALE][domainname])

        else if @LOCALE_DATA[@LOCALE] isnt undefined
            # didn't find domain we're looking for. Search all of them.
            for own dom, val of @LOCALE_DATA[@LOCALE]
                locale_data.push(val)

        trans = []
        found = false
        domain_used # so we can find plural-forms if needed

        if locale_data.length
            for _locale_ in locale_data
                if is_valid_object(_locale_.msgs[msg_ctxt_id])

                    # make copy of that array (cause we'll be destructive)
                    trans = (x for x in _locale_.msgs[msg_ctxt_id])
                    # throw away the msgid_plural
                    trans.shift()

                    domain_used = _locale_
                    found = true

                    # only break if found translation actually has a translation.
                    if trans.length > 0 and trans[0].length isnt 0
                        break

        # default to english if we lack a match, or match has zero length
        if trans.length is 0 or trans[0].length is 0
            trans = [msgid, msgid_plural]

        translation = trans[0]

        if plural
            p = if found and is_valid_object(domain_used.head.plural_func)
                rv = domain_used.head.plural_func(n)

                rv.plural = 0 unless rv.plural
                rv.nplural = 0 unless rv.nplural

                # if plurals returned is out of bound for total plural forms
                rv.plural = 0 if rv.nplural <= rv.plural

                rv.plural
            else
                if n isnt 1 then 1 else 0

            translation = trans[p] if is_valid_object(trans[p])

        translation

    # utility method, since javascript lacks a printf
    strargs: (str, args) ->
        # make sure args is an array
        if args in [null, undefined]
            args = []
        else if (args.constructor isnt Array)
            args = [args]

        # NOTE: javascript lacks support for zero length negative look-behind
        # in regex, so we must step through w/ index.
        # The perl equiv would simply be:
        #    $string =~ s/(?<!\%)\%([0-9]+)/$args[$1]/g
        #    $string =~ s/\%\%/\%/g # restore escaped percent signs

        newstr = ""
        while true
            i = str.indexOf('%')

            # no more found. Append whatever remains
            if i is -1
                newstr += str
                break

            # we found it, append everything up to that
            newstr += str.substr 0, i

            # check for escpaed %%
            if str.substr(i, 2) is '%%'
                newstr += '%'
                str = str.substr i + 2

            # % followed by number
            else if match_n = str.substr(i).match(/^%(\d+)/)
                arg_n = parseInt match_n[1], 10
                length_n = match_n[1].length

                if arg_n > 0 and args[arg_n - 1] not in [null, undefined]
                    newstr += args[arg_n - 1]

                str = str.substr((i + 1 + length_n))

            # % followed by some other garbage - just remove the %
            else
                newstr += '%'
                str = str.substr i + 1

        newstr


module.exports = Gettext
