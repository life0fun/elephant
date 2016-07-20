{assert} = require('chai')
request = require('request')
spdyRequest = require('spdy-request')


###
# Assert expected response status.
#
# @param {dictionary} options - https request options.
# @param {int} statusCode - expected HTTP status code.
# @param {function} done - test done callback.
###
exports.assertResponse = (options, statusCode, done) ->

    request options, (error, response, body) ->
      
        if error then return done(error)
            
        assert.equal response.statusCode, statusCode
        done null, response, body
 
###
# Assert expected SPDY response status.
#
# @param {dictionary} options - https request options.
# @param {int} statusCode - expected HTTP status code.
# @param {function} done - test done callback.
###
exports.assertSpdyResponse = (options, statusCode, done) ->

    spdyRequest options, (error, response, body) ->

        if error then return done(error)

        assert.equal response.statusCode, statusCode
        done null, response, body


