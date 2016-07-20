#
# A http client using restler
# -----------
#

url = require 'url'
util = require 'util'
EventEmitter2 = require('eventemitter2').EventEmitter2

Node = require('../common/root')
rest = require('restler')

#
class RestClient
    constructor: (@uaName) ->

    @create : (uaName) ->
        Node.log 'starting restful client : ', uaName
        return new RestClient(uaName)

    get : (url, cb) ->
        rest.get(url).on 'complete', (result) ->
            # retry logic need to be in app layer
            if result instanceof Error
                Node.logInfo 'get request error: ', result.message
                retry(5000)
            else
                cb result

    # post to request callback in app server
    post: (url, hdr, data, cb) ->
        headers = 
            'content-length': data.length,
            'user-agent' : @uaName,
            'X-Push-Transaction-Id' : hdr['X-Push-Transaction-Id'],
            'X-Push-Delivery-Result': hdr['X-Push-Delivery-Result']

        util._extend(headers, hdr)

        postreq = rest.post url, {headers: headers, data: data}
        postreq.removeAllListeners().on 'error', ->
        postreq.on 'complete', (data, response) ->
            resp = response
            if response
                resp = response.statusCode
                cb null, resp
            if resp == 404
                cb 'error', data
            else
                cb null, data

exports.RestClient = RestClient
