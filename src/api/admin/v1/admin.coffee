#
# Admin v1 API request handler.
#

async = require('async')
HttpStatus = require('http-status-codes')

Logging = require('../../../common/logging')
validate = require('../../../common/validate')
{jsonify} = require('../../../common/request')


###
# Admin request handling.
###
class Admin

    logger = Logging.getLogger "admin-v1"
    auditLogger = Logging.getAuditLogger "accounting"

    ###
    # validate admin/client request.
    ###
    @_validateClientRequest: (req) ->

        (next) =>
        
            async.waterfall [

                validate.isGet(req),
                validate.acceptsJson(req)

            ], next

    @_getClient: (req) ->

        (next) ->

            req.app.clientmap.getClient req.params.pushId, (err, client) ->
                
                if err
                    return next Error.http HttpStatus.INTERNAL_SERVER_ERROR,
                                           "Internal DB Error",
                                           {},
                                           err

                if not client
                    return next Error.http HttpStatus.NOT_FOUND, "Not Found"

                next null, client

    ###
    # handle 'client' api request.
    ###
    @getClient: (req, res) =>

        async.waterfall [

            @_validateClientRequest(req),
            @_getClient(req),

        ], (error, client) ->

            if error
                # attach request params to error data
                error.params = req.params

                logger.info "admin/client error", { error: Error.toJson(error) }
                jsonify res, error.status, { error: error.message }
            else
                jsonify res, HttpStatus.OK, {
                    push_id: client.pushId
                    connected_ts: client.timestamp
                    hostname: client.serverId
                    worker_id: client.workerId
                }

            auditLogger.audit {
                event: "admin-getClient"
                success: not error
                code: error?.status or HttpStatus.OK
                message: error?.message
                extra:
                    pushId: req.params.pushId
            }

    ###
    # common validate revoke request.
    ###
    @_validateRevokeRequest: (req) ->

        (next) ->
        
            async.waterfall [

                validate.isPost(req),
                validate.isJson(req),
                validate.parseJson(req)

            ], next

    @_parseRevokeClientId: (req) ->

        (next) ->
            
            clientId = req.body.clientId
            
            if not clientId
                return next Error.http HttpStatus.BAD_REQUEST, "Missing clientId"

            req.params.clientId = clientId
            next null

    @_parseRevokePushId: (req) ->

        (next) ->

            clientId = req.body.clientId
            pushId = req.body.pushId
            
            if not clientId
                return next Error.http HttpStatus.BAD_REQUEST, 'Missing clientId'

            if not pushId
                return next Error.http HttpStatus.BAD_REQUEST, "Missing pushId"

            req.params.clientId = clientId
            req.params.pushId = pushId
            next null

    @_revokeClientId: (req) ->
    
        (next) ->

            req.app.blacklist.revokeClientId req.params.clientId, (err) ->
                
                if err
                    return next Error.http HttpStatus.INTERNAL_SERVER_ERROR,
                                           "Internal DB Error",
                                           {},
                                           err

                next null

    @_revokePushId: (req) ->

        (next) ->

            req.app.blacklist.revokePushId req.params.pushId, req.params.clientId, (err) ->

                if err
                    return next Error.http HttpStatus.INTERNAL_SERVER_ERROR,
                                           "Internal DB Error",
                                           {},
                                           err
                
                next null

    ###
    # Revoke client API, for test purpose only.
    # handle revoke clientId
    ###
    @revokeClientId: (req, res) =>
    
        async.waterfall [
            
            @_validateRevokeRequest(req),
            @_parseRevokeClientId(req),
            @_revokeClientId(req)
        
        ], (error) ->

            if error
                # attach request params to error data
                error.params = req.params
       
                logger.info "admin/revokeClient error", { error: Error.toJson(error) }
                jsonify res, error.status, { error: error.message }
            else
                res.end "client #{req.params.clientId} revoked !"
                
            auditLogger.audit {
                event: "revoke-clientId"
                success: not error
                code: error?.status or 200
                extra:
                    clientId: req.params.clientId
            }

    # handle revoke pushId
    @revokePushId: (req, res) =>
 
        async.waterfall [
            
            @_validateRevokeRequest(req),
            @_parseRevokePushId(req),
            @_revokePushId(req)

        ], (error) ->

            if error
                # attach request params to error data
                error.params = req.params
       
                logger.info "admin/revokePush error", { error: Error.toJson(error) }
                jsonify res, error.status, { error: error.message }
            else
                res.end "pushId #{req.params.pushId} revoked !"
               
            auditLogger.audit {
                event: "revoke-pushId"
                success: not error
                code: error?.status or 200
                extra:
                    pushId: req.params.pushId
            }


module.exports = Admin
