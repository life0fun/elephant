#
# Register V2 Api request handler.
#

async = require('async')

Logging = require('../../common/logging')
validate = require('../../common/validate')
{jsonify, recordTiming} = require('../../common/request')
{ClientId, PushId} = require('../../model/clientpushid')
PoolLayer = require('../../pool/poollayer')


###
# Register request handling.
###
class Register

    logger = Logging.getLogger "register-v2"
    auditLogger = Logging.getAuditLogger "accounting"

    METADATA_KEYS = [
        "buildVersion",
        "fingerprint",
        "model",
        "network",
        "osVersion",
        "releaseVersion"
    ]

    ###
    # validate posted json
    ###
    @validateJson: (req) ->

        (next) ->

            missingKeys = METADATA_KEYS.filter (key) ->
                not req.body.hasOwnProperty(key)

            if missingKeys.length > 0
                logger.info "register v2 missing #{missingKeys}"
                next Error.http 400, "missing #{missingKeys}"
            else
                next null

    ###
    # validate register request.
    ###
    @validate: (req) ->

        (next) =>

            async.waterfall [

                validate.isSpdy(req),
                validate.isPost(req),
                validate.isJson(req),
                validate.acceptsJson(req),
                validate.validateClientBasicAuth(req),
                validate.parseJson(req),
                @validateJson(req),

            ], next

    @generateClientId: (req) ->

        (next) ->

            workerId = PoolLayer.getWorkerId()
            clientId = ClientId.generateClientId workerId

            logger.info "generated clientId"

            if not clientId
                next Error.http 500, "Could not generate clientId"
            else
                next null, clientId

    @generatePushId: (req) ->

        (clientId, next) ->

            pushId = PushId.generatePushId clientId, 0
            next null, clientId, pushId

    @logSuccess: (pushId) ->
    
        logger.info "clientId and pushId registered", {
            pushId: pushId
        }

        auditLogger.audit {
            event: "client-register"
            success: true
            code: 200
            extra: {
                pushId: pushId
                version: "v2"
            }
        }

    @logFailure: (error) ->
    
        logger.info "client register error", { error: Error.toJson(error) }

        auditLogger.audit {
            event: "client-register"
            success: false
            code: error.status
            error: error.message
            extra: {
                version: "v2"
            }
        }

    ###
    # handle client register request.
    ###
    @handle: (req, res) =>
        
        self = @
        start = Date.now()

        async.waterfall [

            @validate(req),
            @generateClientId(req),
            @generatePushId(req),

        ], (error, clientId, pushId) ->

            if error
                # attach request params to error data
                error.params = req.params

                self.logFailure error

                jsonify res, error.status, {
                    error: error.message
                }
            else
                self.logSuccess pushId

                jsonify res, 200, {
                    client_id: clientId
                    push_id: pushId
                }

            recordTiming req.app.statsd, "register", start, error


module.exports = Register
