{spawn} = require 'child_process'


build = ->
    coffee = spawn 'coffee', ['-c', '-o', 'lib', 'src']

    coffee.stderr.on 'data', (data) ->
        process.stderr.write data.toString()

    coffee.stdout.on 'data', (data) ->
        print data.toString()

    coffee.on 'exit', (code) ->
        console.log "easy-opts build is done"


task 'build', 'Build coffe to lib/ from src/', -> build()
