#
# Application Push Dispatch Tests.
#

{assert} = require('chai')
fs = require('fs')
https = require('https')
HttpStatus = require('http-status-codes')

{assertResponse} = require('./utils')
{jsonify} = require('../src/common/request')
Config = require('../src/config/config')
HttpContentType = require('../src/common/content-type')


suite 'Push Dispatch', ->

    setup (done) ->

        @baseUrl = "https://localhost:#{Config.getConfig('APP_PORT')}/application/v2/"

        @options =
            method: "POST"
            strictSSL: false
            auth:
                user: "default"
                pass: "secret"
            json:
                message: "hello"

        @setPushId = (pushId) ->
            @options.url = "#{@baseUrl}#{pushId}"

        @setPushId 'puid-30'

        keys = Config.getConfig 'KEYS'
        httpsOptions =
            key: fs.readFileSync keys.key
            cert: fs.readFileSync keys.cert

        # mock a peer elephant server
        @server = https.createServer httpsOptions, (req, res) =>

            assertProxyRequestHeaders req.headers
            # request handling logic overriden by each test
            @requestHandler req, res

        @server.listen 8444, done
    
    teardown (done) ->

        @server.close(done)

    ###
    # assert push dispatch response.
    ###
    assertDispatchResponse = (options, statusCode, done) ->
        
        assertResponse options, statusCode, (err, res, body) ->

            if err then return done(err)
            # verify that response contains proxy headers
            assert.property res.headers, 'via'
            done null, res, body

    ###
    # verify that the forwarded push request contains proxy headers.
    ###
    assertProxyRequestHeaders = (headers) ->

        assert.property headers, 'via'
        assert.property headers, 'x-forwarded-for'

    test 'should proxy request and 200 OK response', (done) ->

        @requestHandler = (req, res) ->

            jsonify res, HttpStatus.OK, request_id: 'abcd'

        assertDispatchResponse @options, HttpStatus.OK, (err, res, body) ->

            if err then return done(err)
            assert.propertyVal body, 'request_id', 'abcd'
            done()

    test 'should proxy request and 400 Bad Request response', (done) ->

        @requestHandler = (req, res) ->

            jsonify res, HttpStatus.BAD_REQUEST, error: 'bad, bad request'

        assertDispatchResponse @options, HttpStatus.BAD_REQUEST, (err, res, body) ->

            if err then return done(err)
            assert.property body, 'error'
            done()
    
    test 'should proxy request and 415 response with no body', (done) ->

        @requestHandler = (req, res) ->

            res.writeHead HttpStatus.UNSUPPORTED_MEDIA_TYPE
            res.end()

        assertDispatchResponse @options, HttpStatus.UNSUPPORTED_MEDIA_TYPE, done
 
    test 'should proxy request and 500 response with no body', (done) ->

        @requestHandler = (req, res) ->

            res.writeHead HttpStatus.INTERNAL_SERVER_ERROR
            res.end()

        assertDispatchResponse @options, HttpStatus.INTERNAL_SERVER_ERROR, done

    test 'should return 504 if request to peer server times out', (done) ->

        # request handler does not reply, to force T/O
        @requestHandler = (req, res) ->

        assertResponse @options, HttpStatus.GATEWAY_TIMEOUT, done

    test 'should return 502 if request to peer server unreachable', (done) ->

        @setPushId 'puid-31'        

        assertResponse @options, HttpStatus.BAD_GATEWAY, done

    test 'should return 502 for error from upstream server', (done) ->

        @requestHandler = (req, res) ->

            # forcibly close the socket
            res.connection.socket.destroy()

        assertResponse @options, HttpStatus.BAD_GATEWAY, done

    test 'should return 502 if request already forwarded', (done) ->

        @options.headers =
            via: "elephant/1.1.1 some-host"

        assertResponse @options, HttpStatus.BAD_GATEWAY, done
