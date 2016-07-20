#
# Application Push v2 API Tests.
#

{assert} = require('chai')
HttpStatus = require('http-status-codes')

Config = require('../src/config/config')
HttpContentType = require('../src/common/content-type')
{revokePushId} = require('./revoke')
{assertResponse} = require('./utils')

suite 'Push API v2', ->

    longString = Array(2000).join '*'

    setup ->

        @baseUrl = "https://localhost:#{Config.getConfig('APP_PORT')}/application/v2/"

        @options =
            method: "POST"
            strictSSL: false
            auth:
                user: "default"
                pass: "secret"
            headers:
                "Content-Type": HttpContentType.JSON
            json:
                message: "hello"
                callback:
                    url: "https://example.com"
                    username: "username"
                    password: "password"

        @setPushId = (pushId) ->
            @options.url = "#{@baseUrl}#{pushId}"

        @setPushId 'puid-11'
    
    ###
    # helper function to verify that a 200 response contains a request id.
    ###
    assertRequestId = (done) ->

        (err, response, body) ->

            if err then return done(err)
            assert.property body, 'request_id'
            done()

    test 'should respond 405 to GET', (done) ->

        @options.method = 'GET'
        delete @options.json
        assertResponse @options, HttpStatus.METHOD_NOT_ALLOWED, done

    test 'should respond 415 if no content-type', (done) ->

        delete @options.headers["Content-Type"]
        delete @options.json

        assertResponse @options, HttpStatus.UNSUPPORTED_MEDIA_TYPE, done

    test 'should respond 415 to unsupported content-type', (done) ->

        @options.headers["Content-Type"] = "notjson"
        delete @options.json

        assertResponse @options, HttpStatus.UNSUPPORTED_MEDIA_TYPE, done

    test 'should return 415 when wrong content-type is used', (done) ->
    
        @options.headers["Content-Type"] = HttpContentType.FORM_ENCODED
        delete @options.json

        assertResponse @options, HttpStatus.UNSUPPORTED_MEDIA_TYPE, done

    test 'should respond 401 if no authorization header', (done) ->

        delete @options.auth
    
        assertResponse @options, HttpStatus.UNAUTHORIZED, done

    test 'should respond 401 if bad auth header', (done) ->

        @options.headers["Authorization"] = "bad header"
        delete @options.auth
    
        assertResponse @options, HttpStatus.UNAUTHORIZED, done

    test 'should respond 401 if wrong credentials', (done) ->

        @options.auth =
            user: "wrong"
            pass: "credentials"
    
        assertResponse @options, HttpStatus.UNAUTHORIZED, done

    test 'should respond 400 if no body', (done) ->

        delete @options.json
    
        assertResponse @options, HttpStatus.BAD_REQUEST, done

    test 'should respond 400 if bad body', (done) ->

        @options.json = "notjson"
    
        assertResponse @options, HttpStatus.BAD_REQUEST, done

    test 'should respond 400 if message missing', (done) ->

        delete @options.json.message
    
        assertResponse @options, HttpStatus.BAD_REQUEST, done

    test 'should respond 400 if message too long', (done) ->

        @options.json.message = longString

        assertResponse @options, HttpStatus.BAD_REQUEST, done

    test 'should respond 400 if callback url missing', (done) ->

        delete @options.json.callback.url

        assertResponse @options, HttpStatus.BAD_REQUEST, done

    test 'should respond 400 if invalid callback url protocol', (done) ->

        @options.json.callback.url = "ftp://foo"

        assertResponse @options, HttpStatus.BAD_REQUEST, done

    test 'should respond 400 if callback username missing', (done) ->

        delete @options.json.callback.username

        assertResponse @options, HttpStatus.BAD_REQUEST, done

    test 'should respond 400 if callback password missing', (done) ->

        delete @options.json.callback.password

        assertResponse @options, HttpStatus.BAD_REQUEST, done

    test 'should respond 400 if callback has credentials but not HTTPS', (done) ->

        @options.json.callback.url = "http://example.com"

        assertResponse @options, HttpStatus.BAD_REQUEST, done

    test 'should respond 400 if callback username too long', (done) ->

        @options.json.callback.username = longString

        assertResponse @options, HttpStatus.BAD_REQUEST, done

    test 'should respond 400 if callback password too long', (done) ->

        @options.json.callback.password = longString

        assertResponse @options, HttpStatus.BAD_REQUEST, done

    test 'should respond 404 if client not connected', (done) ->

        @setPushId "puid-not-connected"
    
        assertResponse @options, HttpStatus.NOT_FOUND, done

    test 'should respond 200 for push with callback and credentials', (done) ->

        @setPushId 'puid-22'

        assertResponse @options, HttpStatus.OK, assertRequestId(done)

    test 'should respond 200 for push without callback', (done) ->

        delete @options.json.callback
        @setPushId 'puid-23'

        assertResponse @options, HttpStatus.OK, assertRequestId(done)
    
    test 'should respond 200 for content-type with charset', (done) ->

        @options.headers['Content-Type'] = 'application/json; charset=UTF-8'
        @setPushId 'puid-21'

        assertResponse @options, HttpStatus.OK, assertRequestId(done)
    
    test 'should respond 200 for push with callback but no credentials', (done) ->

        delete @options.json.username
        delete @options.json.password
        @setPushId 'puid-24'

        assertResponse @options, HttpStatus.OK, assertRequestId(done)

    test 'should respond 410 if push id revoked', (done) ->

        revokePushId 'clid-25', 'puid-25', (err, res) =>

            if err then return done(err)
            assert.equal res.statusCode, HttpStatus.OK

            @setPushId 'puid-25'
            assertResponse @options, HttpStatus.GONE, done
