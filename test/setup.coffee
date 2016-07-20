{EventEmitter} = require('events')

elephant = require('../src/app')


###
# unit test setup that starts an elephant server.
###
suite 'Unit Test Setup', ->

    app = undefined
    promise = undefined

    setup (done) =>
        # start test only when server is up.
        if not promise
            promise = new EventEmitter
            promise.once 'success', (workerId) ->
                done()

        if not app
            app = elephant(promise)
        else
            done()

    teardown (done) ->
        done()

    # a suite needs at least one test for mocha to run it
    test 'setup', ->
