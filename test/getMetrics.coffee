#!/usr/bin/env coffee

#
# query elephant server metrics api to get server metrics
#

rest = require('restler')

class RestClient

    constructor: (@uaName) ->

    @create : (uaName) ->
        console.log 'starting restful client : ', uaName
        return new RestClient(uaName)

    # get json, url must have http header, dummy !!!
    get : (url, options, cb) ->
        console.log url, options
        rest.get(url).on 'complete', (result) ->
            # retry logic need to be in app layer
            if result instanceof Error
                console.log 'get request error: ', result.message
                cb result, null
            else
                cb null, result

    # post to request callback in app server
    post: (clientId, url, hdr, data, cb) ->
        headers = {
            'content-type': 'plain/text',
            'content-length' : data.length,
            'user-agent' : @uaName,
            'X-Push-Transaction-Id' : hdr['X-Push-Transaction-Id'],
            'X-Push-Delivery-Result': hdr['X-Push-Delivery-Result']
        }
        util._extend(headers, hdr)

        rest.post(url, {
            headers: headers,
            data: data
        }).on 'complete', (data, response) ->
            resp = response
            if response
                resp = response.statusCode
                cb null, resp
            if resp == 404
                cb 'error', data
            else
                cb null, data

exports.RestClient = RestClient

#
# get request to elephant metrics server
#
class ElephantMetrics

    SERVER_URL = 'localhost'

    constructor : ->
        @headers = {}
        @rest = RestClient.create 'metrics'
        console.log 'elephant metrics'

    @create : ->
        return new ElephantMetrics

    getMetrics : (url, options)->
        console.log 'get metrics :', url
        @rest.get url, options, (err, data) =>
            if err
                console.log 'get url err :', url, err
                return
            else
                # console.log '---- server metrics ----'
                # console.log data
                # for k of data['']
                #     console.log data['']['app_push_req_timer']

                @dumpMetrics data

    dumpMetrics: (data) ->
        console.log '---- server metrics ----'
        for k of data['']    # we did not set a name for this metrics ?
            m = data[''][k]
            mtype = m['type']
            if mtype is 'timer'
                console.log k
                for tk of m
                    console.log tk, m[tk]
            else
                console.log k, m


exports.ElephantMetrics = ElephantMetrics


# unit
options = {
    headers : {
        'host': 'localhost',
        'port': 9091
    }
}
url = 'http://elephant-cte.colorcloud.com:9091/metrics'
url = 'http://localhost:9091/metrics'
metrics = ElephantMetrics.create {}
metrics.getMetrics url, options
