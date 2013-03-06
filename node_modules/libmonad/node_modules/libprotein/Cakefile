{spawn} = require 'child_process'

build = (callback) ->
    coffee = spawn 'coffee', ['-c', 'index.coffee']

    coffee.stderr.on 'data', (data) ->
        process.stderr.write data.toString()

    coffee.stdout.on 'data', (data) ->
        process.stdout.write data.toString()

    coffee.on 'exit', (code) ->
        console.log "Build done, rc:", code


task 'build', 'Build', -> build()
