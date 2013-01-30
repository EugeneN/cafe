{print} = require 'util'
{spawn} = require 'child_process'
{exec} = require 'child_process'
fs = require 'fs'
uuid = require 'node-uuid'


{VERSION_FILE_PATH} = require './src/defs'

inc_version = ->
    fs.writeFileSync VERSION_FILE_PATH, (JSON.parse (fs.readFileSync './package.json')).version

build = (callback) ->
    coffee = spawn 'coffee', ['-c', '-o', 'lib-js', 'src']

    coffee.stderr.on 'data', (data) ->
        process.stderr.write data.toString()

    coffee.stdout.on 'data', (data) ->
        print data.toString()

    coffee.on 'exit', (code) ->
        console.log "Build is done"

        inc_version()

        callback?() if code is 0

gzip = (cb) ->
        gz_file = "cafe.tar.gz"
        tgz = exec(
            "cd .. && tar cf - 'cafe' | gzip -f9 > '#{gz_file}'",
            {},
            (error, stdout, stderr) ->
                if error isnt null
                    console.log "Failed to make a tarball: #{error}"
                else
                    console.log "Made tarball: '../#{gz_file}'"
                    cb?()
        )

install = ->
        tgz = exec(
            "sudo npm install -g ../cafe.tar.gz",
            {},
            (error, stdout, stderr) ->
                    console.log "npm install failed: #{error}" if error isnt null
        )

deps = ->
    x = exec(
        '''egrep 'require(\s|\()+?[^\.@{]+$' */**/*.coffee -n|awk -F= '{print $2}'|egrep \'\|\"|awk -F\'\|\" '{print $2}'|sort|uniq|sort|uniq'''
        {}
        (err, stdout, stderr) ->
            if err isnt null
                console.log stdout
            else
                console.log err, stdout, stderr
    )


task 'deps', 'Grep deps for require', -> deps()

task 'build', 'Build lib-js/ from src/', -> build()

task 'cafebuild', 'builds code from cafe', -> build()

# build from sublime
task 'sbuild', 'The same as `build`, just to call from sublime', -> build()

task 'gzip', 'Create an npm tar.gz package', -> gzip()

task 'install', 'Install built package globally', -> install()

task 'buildall', 'Build and package everything', ->
    build ->
        gzip ->
            console.log 'Voilà'
