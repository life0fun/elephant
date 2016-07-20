shell = require 'shelljs'

module.exports = (grunt) ->

    tests = [
        'test/setup.coffee',
        'test/test-push-dispatch.coffee',
        'test/test-clientmap.coffee',
        'test/sequelize-test.coffee',
        'test/spdyclient-test.coffee',
        'test/test-push-v2.coffee',
        'test/test-refresh-v2.coffee',
        'test/test-listen-v2.coffee',
        'test/test-v1-deprecated.coffee',
        'test/test-register-v2.coffee',
        'test/test-admin-v1.coffee',
        'test/test-ack-v2.coffee'
    ]

    grunt.initConfig
        pkg: grunt.file.readJSON 'package.json'

        mochaTest:
            test:
                options:
                    timeout: 5000
                    ui: 'tdd'
                    reporter: 'spec'
                    require: 'coffee-script'
                src: tests

            build:
                options:
                    timeout: 5000
                    ui: 'tdd'
                    reporter: 'xunit-file'
                    require: 'coffee-script'
                src: tests

        # setup env var for running various tasks
        env:
            test:
                NODE_ENV: 'unit'
            build:
                NODE_ENV: 'unit'
                XUNIT_FILE: 'test/report.xml'
                LOG_XUNIT: 'true'

    # dry-run flag
    nowrite = grunt.option 'no-write'

    grunt.registerTask 'version', 'Append $BUILD_SUFFIX to package version.', ->
        pkg = grunt.file.readJSON 'package.json'
        pkg.version = pkg.version + (process.env.BUILD_SUFFIX or "")
        grunt.file.write 'package.json', JSON.stringify(pkg, null, '    ') + '\n'
        grunt.log.ok 'Package version set to ' + pkg.version

    grunt.registerTask 'install', 'npm install.', (args...) ->
        exec ['npm install', args...].join(' ')

    grunt.registerTask 'cleanmodules', 'Delete node_modules folder.', ->
        exec 'rm -rf node_modules'

    grunt.registerTask 'compile', 'Compile coffeescript to javascript', ->
        exec "./node_modules/.bin/coffee --bare --output lib --compile src"

    exec = (cmd, msg) ->
        if nowrite
            grunt.verbose.writeln 'Dry-run: ' + cmd
        else
            grunt.verbose.writeln 'Running: ' + cmd
            shell.exec cmd

        grunt.log.ok msg if msg


    grunt.loadNpmTasks 'grunt-env'
    grunt.loadNpmTasks 'grunt-mocha-test'

    grunt.registerTask 'default', ['test']
    grunt.registerTask 'test', ['env:test', 'mochaTest:test']
    grunt.registerTask 'build', [
        'version',
        'env:build',
        'mochaTest:build',
        'cleanmodules',
        'install:--production',
        'compile'
    ]
