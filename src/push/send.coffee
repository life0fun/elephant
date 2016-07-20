async = require('async')

Config = require('../config/config')
Logging = require('../common/logging')
PushTimer = require('./timer')
PushCallback = require('./callback')


###
# handles sending a push message to a spdy client.
###
class SendPush

    logger = Logging.getLogger "send-push"
    auditLogger = Logging.getAuditLogger "accounting"

    constructor: (@app) ->

    @create: (app) ->

        new SendPush app
    
    handle: (msg) ->

        logger.debug "sending push message", msg

        startTs = Date.now()

        async.waterfall [

            @_pushToClient(msg),
            @_startTimer(msg),

        ], (error) =>

            if not error
                logger.info "push message sent", {
                    pushId: msg.pushId
                    requestId: msg.requestId
                    pushIndex: msg.pushIndex
                }
            else
                logger.info "failed to send push", {
                    pushId: msg.pushId
                    requestId: msg.requestId
                    pushIndex: msg.pushIndex
                    error: Error.toJson(error)
                }
        
                @app.statsd.timing 'push.send.failure', Date.now() - startTs

                @_handleFailure msg, error

            @app.statsd.timing 'push.send', Date.now() - startTs
    
            auditLogger.audit {
                event: "send-push"
                success: not error
                message: error?.message or "push message sent"
                extra: {
                    pushId: msg.pushId
                    requestId: msg.requestId
                }
            }

    ###
    # send the push message to the client.
    ###
    _pushToClient: (msg) ->

        (next) =>

            session = @app.sessionManager.getSession msg.clientId
            if not session
                return next Error.http 404, "no active client session"

            session.serverPush msg, (error) ->

                next error, session

    ###
    # start a push timer.
    ###
    _startTimer: (msg) ->

        (session, next) =>

            timer = PushTimer.create msg, session, @app
            timer.start()

            next null

    ###
    # handle a failed push send.
    #
    # @param msg - push request message options.
    # @param error - push send error.
    ###
    _handleFailure: (msg, error) ->

        async.waterfall [

            @_getPushRequest(msg),
            @_sendCallback(error),

        ], (error) ->

            if error
                logger.error "error while handling push send failure", {
                    error: Error.toJson(error)
                    pushId: msg.pushId
                    requestId: msg.requestId
                }

    ###
    # get the  push request from db.
    ###
    _getPushRequest: (msg) ->

        (next) =>

            @app.pushRequestManager.getPushRequestByIndex(
                msg.pushIndex,
                (err, pushRequest) ->

                    if err then return next err

                    if not pushRequest
                        return next Error.create "push request not found"
                
                    next null, pushRequest
            )

    ###
    # send push callback if required.
    ###
    _sendCallback: (error) ->

        (pushRequest, next) =>

            callback = PushCallback.create @app, pushRequest, error
            callback.send()

            next null


module.exports = SendPush
