#!/usr/bin/env coffee

#
# A http client using restler
# we use http client to make restful requests to remote APIs.
# this include make dispatch requests to other elephant servers
# as well as async push request callbacks to sparkle server.
#

Logging = require('../common/logging')
rest = require('restler')

#
# the restful client to make restful requests to remote APIs.
#
class RestClient
    # class static logger
    logger = Logging.getLogger "restclient"

    constructor: (@uaName) ->

    @create: (uaName) ->
        logger.debug 'creating restful client : ', uaName
        return new RestClient(uaName)


    # make get request
    get: (url, onGetResult) ->
        rest.get(url).on 'complete', (result) ->
            if result instanceof Error
                logger.error 'get error: ', result.message
                # app layer decide how to retry
                #retry(5000)

            # pass back result
            onGetResult result

    # post to request callback in app server
    post: (url, headers, data, onPostResult) ->

        # setting content length header here!
        headers['content-length'] = data.length
        params =
            headers: headers,
            data: data

        logger.debug "post to #{url} data #{data}"
        # complete event emited when the request has finished.
        # If error occurred, result is instance of Error,
        # otherwise it contains response data. response has status.
        postreq = rest.post url, params
        # Important! need to clean up all previously registered listeners,
        # otherwise, when retry, all prev listeners will be called.
        # However, you need to keep error handling to prevent error bubbling.
        postreq.removeAllListeners().once 'error', (err) ->
            logger.warn "restler client post error #{err}"

        # now register fresh the listener for this retry.
        postreq.once 'complete', (result, response) ->
            postreq.removeAllListeners()
            onPostResult result, response

exports.RestClient = RestClient
