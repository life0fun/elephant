async = require('async')

Config = require('../config/config')
Logging = require('../common/logging')
{recordTiming} = require('../common/request')
PushCallback = require('./callback')


###
# push request timer.
###
class PushTimer

    logger = Logging.getLogger "push-timer"
    auditLogger = Logging.getAuditLogger "accounting"

    delay = Config.getConfig('PUSH_TIMEOUT') * 1000

    ###
    # create new push timer.
    #
    # @param {object} push - push options.
    # @param {Session} session - client session.
    # @param {object} app - application instance.
    ###
    constructor: (@push, @session, @app) ->

    @create: (push, session, app) ->

        new PushTimer push, session, app

    start: ->

        @timeoutId = setTimeout @onTimeout, delay
        @session.addPushTimer @push.requestId, this
    
        logger.debug "timer started", { requestId: @push.requestId }
    
    cancel: ->

        clearTimeout @timeoutId
        @session.removePushTimer @push.requestId

        logger.debug "timer canceled", { requestId: @push.requestId }

    onTimeout: =>

        logger.debug "timer expired", { requestId: @push.requestId }

        start = Date.now()
    
        async.waterfall [

            @_removeTimer,
            @_getPushRequest,
            @_sendCallback,

        ], (error) =>

            if error
                logger.error "failed to process push timeout", {
                    error: Error.toJson(error)
                    pushIndex: @push.pushIndex
                    pushId: @push.pushId
                    requestId: @push.requestIdreq
                }
            else
                logger.info "push timed out", {
                    pushIndex: @push.pushIndex
                    pushId: @push.pushId
                    requestId: @push.requestId
                }

                auditLogger.audit
                    event: "push-ack"
                    success: false
                    code: 504
                    message: "push timed out"
                    extra:
                        requestId: @push.requestId
                        pushId: @push.pushId

            recordTiming @app.statsd, "push.timeout", start, error
            
    ###
    # remove timer from push timers list.
    ###
    _removeTimer: (next) =>

        if @session.removePushTimer @push.requestId
            next null
        else
            # if timer already removed then push already acked
            # so we do not continue and back out of timeout handling
            logger.debug "timeout back out", { requestId: @push.requestId }
    
    ###
    # get the push request from db and validate its status.
    ###
    _getPushRequest: (next) =>

        @app.pushRequestManager.getPushRequestByIndex  @push.pushIndex, (err, pushRequest) =>

            if err then return next err

            if not pushRequest
                return next Error.create "unkown push index in push timeout"

            @pushRequest = pushRequest
            next null

    ###
    # send push callback if required.
    ###
    _sendCallback: (next) =>

        callback = PushCallback.create @app, @pushRequest, Error.http 504, "push ack timeout"
        callback.send()

        next null


module.exports = PushTimer
