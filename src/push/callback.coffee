request = require('request')
retry = require('retry')
async = require('async')

Logging = require('../common/logging')
Config = require('../config/config')
Helper = require('../common/helper')
{recordTiming} = require('../common/request')


###
# push callback handling.
###
class PushCallback

    logger = Logging.getLogger "push-callback"
    auditLogger = Logging.getAuditLogger "accounting"

    # list of HTTP status codes that indicate a temporary outage
    # on the callback receiver. elephant will retry to send the
    # callback when these status codes are encountered.
    RETRY_STATUS = [502, 503, 504]

    ###
    # create a new push callback instance.
    #
    # @app - object with pushRequestManager db access.
    # @pushRequest {PushRequest} - push request db model.
    # @error {Error} - optional HTTP error object with HTTP status to send in callback.
    ###
    constructor: (@app, @pushRequest, @error) ->

        @retryOptions =
            retries: Config.getConfig 'PUSH_CALLBACK_RETRIES'
            factor: 2

        @requestOptions =
            url: @pushRequest.callbackUrl
            json:
                request_id: pushRequest.requestId
                status: error?.status or 200

        if @pushRequest.callbackUsername?
            @requestOptions.auth = {
                username: @pushRequest.callbackUsername
                password: Helper.aesDecrypt @pushRequest.callbackPassword
            }

    @create: (app, pushRequest, error) ->

        new PushCallback app, pushRequest, error

    ###
    # start the push callback process.
    ###
    send: ->

        async.waterfall [

            @_sendWithRetry,
            @_deletePushRequest
    
        ], (err) =>

            if err
                logger.error "error while sending push callback", {
                    error: Error.toJson(err)
                    requestId: @pushRequest.requestId
                    pushId: @pushRequest.pushId
                }

    ###
    # send the push callback with retires.
    ###
    _sendWithRetry: (next) =>

        if not @pushRequest.callbackUrl
            return next null
    
        self = @
        start = Date.now()
        operation = retry.operation @retryOptions

        operation.attempt (currentAttempt) ->

            self._send currentAttempt, (err, res, body) ->

                if not operation.retry err

                    failed = err or res.statusCode isnt 200
                
                    logger.info "push callback done", {
                        reason:
                            if err
                                "max retries reached"
                            else if res.statusCode isnt 200
                                "response error code #{res.statusCode}"
                            else
                                "sent"
                        requestId: self.pushRequest.requestId
                        pushId: self.pushRequest.pushId
                    }

                    auditLogger.audit {
                        event: "push-callback"
                        success: not failed
                        message: err?.message or ""
                        code: err?.status or res?.statusCode
                        extra: {
                            pushId: self.pushRequest.pushId
                            requestId: self.pushRequest.requestId
                        }
                    }
                    
                    recordTiming self.app.statsd, "push.callback", start, failed

                    next null

    ###
    # internal send push callback.
    #
    # @param {Number} attempt - current attempt number.
    # @param {Function} callback - completion callback accepting (err, response, body).
    ###
    _send: (attempt, callback) ->

        logger.debug "sending push callback", {
            requestId: @pushRequest.requestId
            pushId: @pushRequest.pushId
            url: @pushRequest.callbackUrl
            attempt: attempt
        }

        startTs = Date.now()
    
        request.post @requestOptions, (err, res, body) =>

            @app.statsd.timing "push.callback.attempt", Date.now() - startTs
    
            if err
                logger.info "push callback send error", {
                    requestId: @pushRequest.requestId
                    pushId: @pushRequest.pushId
                    error: Error.toJson(err)
                }
                return callback err

            logger.info "push callback response", {
                requestId: @pushRequest.requestId
                pushId: @pushRequest.pushId
                status: res.status
                body: body
            }
                
            if res.statusCode in RETRY_STATUS
                return callback Error.http res.status, "temporary outage or timeout"

            callback null, res, body
    
    ###
    # delete push request from db.
    ###
    _deletePushRequest: (next) =>

        @app.pushRequestManager.deletePushRequestByIndex @pushRequest.pushIndex, next


module.exports = PushCallback
