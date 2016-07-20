https = require 'https'
{assert} = require('chai')

Config = require('../src/config/config')


suite 'All v1 api should be deprecated', ->

    createClientOptions = (path, method) -> {
        host: 'localhost',
        port: Config.getConfig('SPDY_PORT'),
        rejectUnauthorized: false,
        path: path,
        method: method
    }

    createAppOptions = (path, method) -> {
        host: 'localhost',
        port: Config.getConfig('APP_PORT'),
        rejectUnauthorized: false,
        path: path,
        method: method
    }
    

    # --------------------------------------------------------------------------
    #  client v1
    # --------------------------------------------------------------------------
    
    test 'should respond 404 to v1 register', (done) ->
        https.request(createClientOptions('/client/v1/register', 'POST'), (res) ->
            assert.equal res.statusCode, 404, "respond 404 for v1 register"
            done()
        ).end()

    test 'should respond 404 to v1 listen', (done) ->
        https.request(createClientOptions('/client/v1/puid-0', 'GET'), (res) ->
            assert.equal res.statusCode, 404, "respond 404 for v1 listen"
            done()
        ).end()

    test 'should respond 404 to v1 ack', (done) ->
        https.request(createClientOptions('/client/v1/ack', 'POST'), (res) ->
            assert.equal res.statusCode, 404, "respond 404 for v1 ack"
            done()
        ).end()

    test 'should respond 404 to v1 refresh', (done) ->
        https.request(createClientOptions('/client/v1/refresh', 'POST'), (res) ->
            assert.equal res.statusCode, 404, "respond 404 for v1 refresh"
            done()
        ).end()

    # --------------------------------------------------------------------------
    #  app v1
    # --------------------------------------------------------------------------

    test 'should respond 404 to v1 push', (done) ->
        https.request(createAppOptions('/application/v1/puid-22', 'POST'), (res) ->
            assert.equal res.statusCode, 404, "respond 404 for v1 push"
            done()
        ).end()
