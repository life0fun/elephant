os = require('os')
request = require('request')

Config = require('../config/config')
helper = require('../common/helper')
Logging = require('../common/logging')


###
# Push Request Dispatcher.
#
# when load balancing, push requests might be sent to a server that does not
# have the designated device connected. Hence the server needs to dispatch
# request to the host that has the device.
###
class Dispatcher

    logger = Logging.getLogger "dispatcher"

    ###
    # dispatch push request to peer elephant server.
    # @param {Request} req - the original push request object.
    # @param {string} serverId - peer elephant server IP:port.
    # @param {Function} callback - with (error, response, body) signature.
    ###
    @dispatch: (req, serverId, callback) ->

        # forwarded push request options
        options =
            url: "https://#{serverId}#{req.url}"
            method: req.method
            headers: req.headers
            timeout: Config.getConfig('DISPATCH_TIMEOUT')
            strictSSL: false
    
        # add proxy HTTP request headers
        options.headers["X-Forwarded-For"] = req.socket.remoteAddress
        options.headers["via"] = "elephant/#{helper.getVersion()} #{os.hostname()}"

        logger.debug "forwarding push request",
            requestOptions: options
    
        stream = request options, (error, response, body) ->

            if error
                if error.code in ['ETIMEDOUT', 'ESOCKETTIMEDOUT']
                    callback Error.http 504, "request to upstream server timed out", {}, error
                else
                    callback Error.http 502, error.message, {}, error
            else
                # add proxy HTTP response headers
                response.headers["via"] = options.headers["via"]
    
                callback null, response, body

        req.pipe stream

    ###
    # check if the push request is forwarded.
    ###
    @isForwarded: (req) ->

        'via' of req.headers


module.exports = Dispatcher
