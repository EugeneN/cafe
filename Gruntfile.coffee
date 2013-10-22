matchdep = require('matchdep')

module.exports = (grunt) ->
    matchdep.filterDev('grunt-*').forEach grunt.loadNpmTasks;

    grunt.config.init
        watch:
            src:
                files: "src/**/*.coffee"
                tasks: ["build"]
            
        coffee:
            src:
                expand: true
                cwd: "src/"
                src: "**/*.coffee"
                dest: "lib-js/"
                ext: ".js"

        nodeunit:
            all: ['test/**/test*.coffee']

    grunt.registerTask 'build', ['nodeunit', 'coffee']
