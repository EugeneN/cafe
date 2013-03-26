npm = require 'npm'
OK = undefined


run_install_in_dir = (dirpath, cb) ->
    config =
        prefix: dirpath
        _exit: true

    npm.load config, (err, cnpm) ->
        (throw "Failed to load config for npm #{err}") if err
        # very important, do not remove
        cnpm.config.set 'prefix', dirpath
        cnpm.prefix = dirpath

        cnpm.commands.install [], (err, info) ->
            if err
                cb err, info
            else
                cb OK, info


install_module = (module_name, dirpath, cb) ->
    config =
        prefix: dirpath
        _exit: true

    npm.load config, (err, cnpm) ->
        (throw "Failed to load config for npm #{err}") if err

        cnpm.commands.install [module_name], (err, info) ->
            if err
                cb err, info
            else
                cb OK, info



module_installed = (module_name, dirpath, cb) ->


module.exports = {run_install_in_dir, install_module}