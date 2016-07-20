#
# Client Listen API Tests.
#

{assert} = require('chai')
HttpStatus = require('http-status-codes')

Config = require('../src/config/config')
{revokeClientId, revokePushId} = require('./revoke')
{assertSpdyResponse} = require('./utils')


suite 'Listen API v2', ->

    setup ->

        @setRequestPath =  (pingInterval) ->
            @options.path = @basePath
            if pingInterval
                @options.path += "?min_ping_interval_sec=#{pingInterval}"

        @basePath = '/client/v2/puid-0'

        @options =
            host: 'localhost'
            port: Config.getConfig('SPDY_PORT')
            rejectUnauthorized: false
            poll: true
            method: 'GET'
            headers:
                "Authorization": "Basic clid-0"
                "Accept": "application/json"

        @setRequestPath(600)

    test 'should respond 400 if missing min_ping_interval_sec', (done) ->

        @setRequestPath()
    
        assertSpdyResponse @options, HttpStatus.BAD_REQUEST, done

    test 'should respond 400 if min_ping_interval_sec is 0', (done) ->

        @setRequestPath(0)
    
        assertSpdyResponse @options, HttpStatus.BAD_REQUEST, done

    test 'should respond 400 if min_ping_interval_sec is < 0', (done) ->

        @setRequestPath(-10)
    
        assertSpdyResponse @options, HttpStatus.BAD_REQUEST, done

    test 'should respond 400 if min_ping_interval_sec is NaN', (done) ->

        @setRequestPath('1a')
    
        assertSpdyResponse @options, HttpStatus.BAD_REQUEST, done

    test 'should respond 405 to POST', (done) ->

        @options.method = 'POST'
    
        assertSpdyResponse @options, HttpStatus.METHOD_NOT_ALLOWED, done

    test 'should respond 406 if accept is invalid', (done) ->

        @options.headers["Accept"] = "notjson"

        assertSpdyResponse @options, HttpStatus.NOT_ACCEPTABLE, done

    test 'should respond 406 if accept is not application/json', (done) ->

        @options.headers["Accept"] = "text/plain"

        assertSpdyResponse @options, HttpStatus.NOT_ACCEPTABLE, done

    test 'should respond 401 if no authorization header', (done) ->

        delete @options.headers["Authorization"]
    
        assertSpdyResponse @options, HttpStatus.UNAUTHORIZED, done

    test 'should respond 401 if bad auth header', (done) ->

        @options.headers["Authorization"] = "bad header"
    
        assertSpdyResponse @options, HttpStatus.UNAUTHORIZED, done

    test 'should respond 200 for valid listen request', (done) ->

        assertSpdyResponse @options, HttpStatus.OK, (err, res, body) ->

            if err then return done(err)
            
            expectedJson =
                reconnect_retry_policy: Config.getConfig 'RETRY_POLICY'
                pingIntervalSec: 600

            # response should include the reconnectPolicy, and pingIntervalSec
            assert.deepEqual(JSON.parse(body), expectedJson, "reconnect_retry_policy equals")

            done()

    test 'should respond 200 and choose a pingInterval twice the min', (done) ->

        serverMinPingSec = Config.getConfig('MIN_SOCKET_TIMEOUT_SEC') / 2
        clientMinPingSec = serverMinPingSec + 100
        @setRequestPath(clientMinPingSec)

        assertSpdyResponse @options, HttpStatus.OK, (err, res, body) ->

            if err then return done(err)
            
            assert.equal JSON.parse(body).pingIntervalSec, clientMinPingSec, "pingInterval equals"

            done()

    test 'should respond 200 and choose a pingInterval based on the serverMin', (done) ->

        # This interval is much smaller than what the server supports.
        # The server should simply choose its smallest allowable min, 600.
        serverMinPingSec = Config.getConfig('MIN_SOCKET_TIMEOUT_SEC') / 2
        clientMinPingSec = serverMinPingSec - 100
        @setRequestPath(clientMinPingSec)

        assertSpdyResponse @options, HttpStatus.OK, (err, res, body) ->

            if err then return done(err)
            
            assert.equal JSON.parse(body).pingIntervalSec, serverMinPingSec, "pingInterval equals"

            done()

    test 'should respond 410 if push id revoked', (done) ->

        revokePushId 'clid-0', 'puid-0', (err, res) =>

            if err then return done(err)
            assert.equal res.statusCode, HttpStatus.OK

            assertSpdyResponse @options, HttpStatus.GONE, done

    test 'should respond 403 if client id revoked', (done) ->

        revokeClientId 'clid-0', (err, res) =>

            if err then return done(err)
            assert.equal res.statusCode, HttpStatus.OK

            assertSpdyResponse @options, HttpStatus.FORBIDDEN, done
