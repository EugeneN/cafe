npm = require 'npm'

run_install_in_dir = (dirpath, cb) ->
		config = 
			prefix: dirpath
			_exit: true
 
		npm.load config, (err) ->
			(throw "Failed to load config for npm #{err}") if err
				
			npm.commands.install [], (err, info) ->
				cb err, info
				
			#npm.on "log", (message) -> console.log message

module.exports = {run_install_in_dir}