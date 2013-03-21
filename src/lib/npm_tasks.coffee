npm = require 'npm'
fs = require 'fs'
path = require 'path'


run_install_in_dir = (dirpath, cb) ->
		config = 
			prefix: dirpath
			_exit: true
 
		npm.load config, (err) ->
			(throw "Failed to load config for npm #{err}") if err
				
			npm.commands.install [], (err, info) ->
				cb err, info
				

install_module = (module_name, dirpath, cb) ->
	config = 
			prefix: dirpath
			_exit: true
 
		npm.load config, (err) ->
			(throw "Failed to load config for npm #{err}") if err
				
			npm.commands.install [module_name], (err, info) ->
				cb err, info


module_installed = (module_name, dirpath, cb) ->


module.exports = {run_install_in_dir, install_module}