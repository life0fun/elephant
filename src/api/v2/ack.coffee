#
# Ack V2 Api request handler.
#

async = require('async')

Logging = require('../../common/logging')
validate = require('../../common/validate')
{jsonify, recordTiming} = require('../../common/request')
PushCallback = require('../../push/callback')


###
# ack request handling.
###
class Ack

    logger = Logging.getLogger "ack-v2"
    auditLogger = Logging.getAuditLogger "accounting"

    ###
    # parse the request id from the request json body.
    ###
    @parseRequestId: (req, res) ->

        (next) ->

            if not req.body.request_id
                next Error.http 400, "missing request_id parameter"
            else
                req.params.requestId = req.body.request_id
                next null
 
    ###
    # validate ack request.
    ###
    @validate: (req) ->

        (next) =>
        
            async.waterfall [

                validate.isSpdy(req),
                validate.isPost(req),
                validate.isJson(req),
                validate.parseClientId(req),
                validate.validateRevokedClientId(req),
                validate.parseJson(req),
                @parseRequestId(req)

            ], next

    ###
    # cancel the pending push timer for the push request.
    ###
    @cancelPushTimer: (req) ->

        (next) ->

            session = req.app.sessionManager.getSession req.params.clientId
            if not session
                return next Error.http 404, "ack session not found"

            timer = session.getPushTimer req.params.requestId
            if not timer
                # push request already acked/timed-out or unknown request id.
                return next Error.http 404, "push timed out or unknown request id"

            timer.cancel()
    
            next null, timer.push

    ###
    # get the updated push request from db and validate its status.
    ###
    @getPushRequest: (req) ->

        (push, next) ->

            req.app.pushRequestManager.getPushRequestByIndex push.pushIndex, (err, pushRequest) ->

                if err
                    return next Error.http 500, "internal DB error", {}, err

                if not pushRequest
                    return next Error.http 404, "push request not found"

                req.params.pushRequest = pushRequest
                next null

    ###
    # send push callback if required.
    ###
    @sendCallback: (req) ->

        (next) ->

            callback = PushCallback.create req.app, req.params.pushRequest
            callback.send()

            next null

    ###
    # handle client ack request.
    ###
    @handle: (req, res) =>

        start = Date.now()
    
        async.waterfall [

            @validate(req),
            @cancelPushTimer(req),
            @getPushRequest(req),
            @sendCallback(req),

        ], (error) ->

            if error
                # attach request params to error data
                error.params = req.params
                logger.info "client ack error", { error: Error.toJson(error) }
        
                jsonify res, error.status, { error: error.message }
            else
                logger.info "client push acked", {
                    requestId: req.params.requestId
                }

                # update how long it takes for push to complete
                pushDuration = Date.now() - req.params.pushRequest.startTime
                req.app.statsd.timing 'push.total', pushDuration

                res.end()

            recordTiming req.app.statsd, "push.ack", start, error

            auditLogger.audit {
                event: "push-ack"
                success: not error
                code: error?.status or 200
                message: error?.message or ""
                extra: {
                    requestId: req.params.requestId
                    pushId: req.params.pushRequest?.pushId
                }
            }

        
module.exports = Ack
