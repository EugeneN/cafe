{spawn} = require 'child_process'

build = () ->
    result = spawn 'coffee', ['-c', '-o', 'lib', 'src']
    result.on 'exit', (code) ->
    	if code is 0
    		console.log 'wrapper-commonjs build is done successfuly'
    	else
    		console.log "wrapper-commonjs build failure exit code - #{code}"

# tasks
task 'build', 'builds wrapper-commonjs', -> build()