#
# Client Refresh API Tests.
#

{assert} = require('chai')
HttpStatus = require('http-status-codes')
spdy = require('spdy')

Config = require('../src/config/config')
{revokeClientId} = require('./revoke')
{assertSpdyResponse} = require('./utils')


suite 'Refresh API v2', ->

    setup ->
        
        @options =
            host: 'localhost'
            port: Config.getConfig('SPDY_PORT')
            path: '/client/v2/refresh'
            rejectUnauthorized: false
            method: 'POST'
            headers:
                "Authorization": "Basic clid-17"
                "Accept": "application/json"
            json:
                push_id: "puid-17"

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

    test 'should respond 406 if accept is invalid', (done) ->

        @options.headers["Accept"] = "notjson"

        assertSpdyResponse @options, HttpStatus.NOT_ACCEPTABLE, done

    test 'should respond 406 if accept is not application/json', (done) ->

        @options.headers["Accept"] = "text/plain"

        assertSpdyResponse @options, HttpStatus.NOT_ACCEPTABLE, done

    test 'should respond 400 if no body', (done) ->

        delete @options.json.push_id
    
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

    test 'should respond 200 for valid refresh request', (done) ->

        assertSpdyResponse @options, HttpStatus.OK, (err, res, body) ->

            if err then return done(err)

            # response should include new push_id
            assert.propertyNotVal body, 'push_id', 'puid-17'
            done()

    test 'should respond 403 if client id revoked', (done) ->

        revokeClientId 'clid-17', (err, res) =>

            if err then return done(err)
            assert.equal res.statusCode, HttpStatus.OK

            assertSpdyResponse @options, HttpStatus.FORBIDDEN, done
