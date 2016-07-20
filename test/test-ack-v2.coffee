#
# Client Ack v2 API Tests.
#

assert = require('chai').assert
ElephantClient = require('elephant-client')
HttpStatus = require('http-status-codes')

Config = require('../src/config/config')
HttpContentType = require('../src/common/content-type')
{revokeClientId} = require('./revoke')
{assertSpdyResponse} = require('./utils')


suite 'Ack API v2', ->

    setup ->

        @clientId = "clid-18"
        @requestId = "request-1"

        @options =
            host: 'localhost'
            port: Config.getConfig('SPDY_PORT')
            rejectUnauthorized: false
            path: '/client/v2/ack'
            method: 'POST'
            headers:
                "Authorization": "Basic #{@clientId}"
            json:
                request_id: @requestId

    test 'should respond 405 to GET', (done) ->

        @options.method = 'GET'
        delete @options.json
    
        assertSpdyResponse @options, HttpStatus.METHOD_NOT_ALLOWED, done

    test 'should respond 415 if no content-type', (done) ->
        
        delete @options.json

        assertSpdyResponse @options, HttpStatus.UNSUPPORTED_MEDIA_TYPE, done

    test 'should respond 415 to unsupported content-type', (done) ->

        @options.headers["Content-Type"] = "notjson"

        assertSpdyResponse @options, HttpStatus.UNSUPPORTED_MEDIA_TYPE, done

    test 'should respond 400 if no body', (done) ->

        delete @options.json
        @options.headers['Content-Type'] = HttpContentType.JSON

        assertSpdyResponse @options, HttpStatus.BAD_REQUEST, done

    test 'should respond 400 if request_id missing', (done) ->

        delete @options.json.request_id
    
        assertSpdyResponse @options, HttpStatus.BAD_REQUEST, done

    test 'should respond 400 if bad body', (done) ->

        @options.json = "notjson"
    
        assertSpdyResponse @options, HttpStatus.BAD_REQUEST, done

    test 'should respond 401 if no authorization header', (done) ->

        delete @options.headers["Authorization"]
    
        assertSpdyResponse @options, HttpStatus.UNAUTHORIZED, done

    test 'should respond 401 if bad auth header', (done) ->

        @options.headers["Authorization"] = "bad header"
    
        assertSpdyResponse @options, HttpStatus.UNAUTHORIZED, done

    test 'should respond 404 if unknown request id', (done) ->

        assertSpdyResponse @options, HttpStatus.NOT_FOUND, done

    test 'should respond 200 for valid ack request', (done) ->

        client = ElephantClient.create()

        pushData =
            message: "hello"

        pushCallback = (err, push) ->

            if err then return done(err)

            assert.equal push.data, pushData.message
    
            client.ack(push.request_id)
            .then(-> done())
            .fail((err) -> done err)

        client.register()
        .then(-> client.listen pushCallback)
        .then(-> client.push pushData)
        .fail((err) -> done err)

    test 'should respond 403 if client id revoked', (done) ->

        revokeClientId @clientId, (err, res) =>

            if err then return done(err)
            assert.equal res.statusCode, HttpStatus.OK

            assertSpdyResponse @options, HttpStatus.FORBIDDEN, done

