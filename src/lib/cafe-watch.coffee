###
    Simple wrapper around wathcer library.
###

chokidar = require 'chokidar'
path = require 'path'
{WATCH_IGNORE} = require '../defs'


watcher = ({paths
         ignored            # optional default - /^\./
         change_handler     # optional
         persistent         # optional default - true
         interval           # optional default - 300
         add_handler        # optional
         remove_handler     # optional
         error_handler}     # optional
         ) ->

    ignored or= WATCH_IGNORE
    interval or= 300
    persistent or=true

    paths = paths.map (p) -> path.resolve p

    watcher = chokidar.watch(
        paths
        {
            ignored
            persistent
            ignoreInitial: true
            interval
            binaryInterval: interval
        })

    if change_handler
        watcher.on 'change', change_handler

    if add_handler
        watcher.on 'add', add_handler

    if remove_handler
        watcher.on 'unlink', remove_handler

    if error_handler
        watcher.on 'error', error_handler

    add: (paths) -> watcher.add paths


module.exports = {watcher}

