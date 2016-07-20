#
# Client Register API Tests.
#

{assert} = require('chai')
HttpStatus = require('http-status-codes')

Config = require('../src/config/config')
{revokeClientId} = require('./revoke')
{assertSpdyResponse} = require('./utils')


suite 'Registration API v2', ->

    setup ->
        @registerMeta =
            buildVersion: "1.4.1"
            fingerprint: "..."
            model: "M9300"
            network: "sprint"
            osVersion: "Android_2.1"
            releaseVersion: 3
            
        @options =
            host: 'localhost'
            port: Config.getConfig('SPDY_PORT')
            path: '/client/v2/register'
            method: 'POST'
            rejectUnauthorized: false
            auth: "default:secret"
            json: @registerMeta
            headers:
                "Accept": "application/json"

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

    test 'should respond 406 if accept is unsupported type', (done) ->

        @options.headers["Accept"] = "plain/text"

        assertSpdyResponse @options, HttpStatus.NOT_ACCEPTABLE, done

    test 'should respond 406 if accept is invalid type', (done) ->

        @options.headers["Accept"] = "notjson"

        assertSpdyResponse @options, HttpStatus.NOT_ACCEPTABLE, done

    test 'should respond 400 if no body', (done) ->

        delete @options.json
        @options.headers["Content-Type"] = "application/json"

        assertSpdyResponse @options, HttpStatus.BAD_REQUEST, done

    test 'should respond 400 if bad body', (done) ->

        @options.json = "notjson"
    
        assertSpdyResponse @options, HttpStatus.BAD_REQUEST, done

    test 'should respond 400 if missing part of body', (done) ->

        delete @options.json.fingerprint
    
        assertSpdyResponse @options, HttpStatus.BAD_REQUEST, done

    test 'should respond 401 if no authorization header', (done) ->

        delete @options.auth
    
        assertSpdyResponse @options, HttpStatus.UNAUTHORIZED, done

    test 'should respond 401 if bad auth header', (done) ->

        @options.headers["Authorization"] = "bad header"
    
        assertSpdyResponse @options, HttpStatus.UNAUTHORIZED, done

    test 'should respond 401 if bad credentials', (done) ->

        @options.auth =
            user: "baduser"
            password: "badpass"
    
        assertSpdyResponse @options, HttpStatus.UNAUTHORIZED, done

    test 'should respond 200 for valid register request', (done) ->

        assertSpdyResponse @options, HttpStatus.OK, (err, res, body) ->

            if err then return done(err)

            # response should include new push_id
            assert.property body, 'client_id'
            assert.property body, 'push_id'
            done()
