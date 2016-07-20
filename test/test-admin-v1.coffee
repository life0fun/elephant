#
# Admin API Tests.
#

{assert} = require('chai')
HttpStatus = require('http-status-codes')
request = require('request')

Config = require('../src/config/config')
HttpContentType = require('../src/common/content-type')
{assertResponse} = require('./utils')

suite 'Admin API v1', ->

    setup ->

        @baseUrl = "https://localhost:#{Config.getConfig('APP_PORT')}/admin/v1/client/"
 
        @options =
            method: 'GET'
            strictSSL: false
            headers:
                "Accept": HttpContentType.JSON

        @setUrl = (pushId) =>
            @options.url = "#{@baseUrl}#{pushId}"
        
        @setUrl 'puid-17'
            
    test 'should respond 405 to POST', (done) ->

        @options.method = 'POST'
    
        assertResponse @options, HttpStatus.METHOD_NOT_ALLOWED, done

    test 'should respond 406 if accept is not application/json', (done) ->

        @options.headers["Accept"] = "notjson"
    
        assertResponse @options, HttpStatus.NOT_ACCEPTABLE, done

    test 'should respond 200 for valid admin/client request', (done) ->

        assertResponse @options, HttpStatus.OK, (error, response, body) ->

            parsedBody = JSON.parse(body)

            assert.propertyVal parsedBody, 'push_id', 'puid-17'
            for field in ['connected_ts', 'hostname', 'worker_id']
                assert.property parsedBody, field
               
            done()
    
    test 'should respond 404 if push id not connected', (done) ->

        @setUrl 'doesnotexist'

        assertResponse @options, HttpStatus.NOT_FOUND, done
