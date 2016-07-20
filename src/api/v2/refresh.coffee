#
# Refresh V2 Api request handler.
#

async = require('async')

Logging = require('../../common/logging')
validate = require('../../common/validate')
{jsonify, recordTiming} = require('../../common/request')
{PushId} = require('../../model/clientpushid')

###
# Refresh request handling.
###
class Refresh

    logger = Logging.getLogger "refresh-v2"
    auditLogger = Logging.getAuditLogger "accounting"

    ###
    # parse the push id from the request json body.
    ###
    @parsePushId: (req, res) ->

        (next) ->

            if not req.body.push_id
                next Error.http 400, "missing push_id"
            else
                req.params.pushId = req.body.push_id
                next null

    ###
    # validate refresh request.
    ###
    @validate: (req) ->

        (next) =>
        
            async.waterfall [

                validate.isSpdy(req),
                validate.isPost(req),
                validate.isJson(req),
                validate.acceptsJson(req),
                validate.parseClientId(req),
                validate.validateRevokedClientId(req),
                validate.parseJson(req),
                @parsePushId(req),
                validate.validatePushId(req)

            ], next

    @incrementRefreshCount: (req) ->

        (next) ->

            req.app.blacklist.incrementRefreshCount req.params.clientId, (err) ->

                if err
                    next Error.http 500, "internal DB error", {}, err
                else
                    next null

    @generatePushId: (req) ->

        (next) ->

            req.app.blacklist.getRefreshCount req.params.clientId, (err, count) ->

                if err
                    return next Error.http 500, "internal DB error", {}, err

                pushId = PushId.generatePushId req.params.clientId, count
                next null, pushId
    
    ###
    # handle client refresh request.
    ###
    @handle: (req, res) =>

        start = Date.now()

        async.waterfall [

            @validate(req),
            @incrementRefreshCount(req),
            @generatePushId(req),

        ], (error, pushId) ->

            if error
                # attach request params to error data
                error.params = req.params

                logger.info "client refresh error", { error: Error.toJson(error) }
                jsonify res, error.status, { error: error.message }
            else
                logger.info "client pushId refreshed", {
                    oldPushId: req.params.pushId
                    pushId: pushId
                }
                jsonify res, 200, { push_id: pushId }

            recordTiming req.app.statsd, "refresh", start, error

            auditLogger.audit {
                event: "refresh"
                success: error?
                code: error?.status or 200
                message: error?.message or ""
                extra: {
                    oldPushId: req.params.pushId?
                    pushId: pushId?
                }
            }


module.exports = Refresh
