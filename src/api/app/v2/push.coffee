#
# Application push API v2 request handler.
#

async = require('async')
url = require('url')

Logging = require('../../../common/logging')
validate = require('../../../common/validate')
{jsonify, recordTiming} = require('../../../common/request')
PushCallback = require('../../../push/callback')
Dispatcher = require('../../../push/dispatch')
PoolLayer = require('../../../pool/poollayer')
{PushRequest} = require('../../../model/pushrequest')


###
# push request handling.
###
class Push

    logger = Logging.getLogger "push-v2"
    auditLogger = Logging.getAuditLogger "accounting"

    MAX_FIELD_SIZE = 1024

    ###
    # handle app push request.
    ###
    @handle: (req, res) =>

        req.params.start = Date.now()
    
        async.waterfall [

            @getClientInfo(req),
            @dispatch(req, res),

        ], (error) =>

            if req.params.dispatch
                @handleDispatchResult req, res, error
            else
                @handleLocalPushResult req, res, error

    @handleLocalPushResult: (req, res, error) ->
    
        if error
            # attach request params to error data
            error.params = req.params
            logger.info "push request error", { error: Error.toJson(error) }
            
            jsonify res, error.status, { error: error.message }
        else
            logger.info "push request created",
                pushId: req.params.pushId
                requestId: req.params.pushRequest.requestId

            jsonify res, 200, { request_id: req.params.pushRequest.requestId }

        recordTiming req.app.statsd, "push.request", req.params.start, error

        auditLogger.audit
            event: "push-request"
            success: not error
            code: error?.status or 200
            message: error?.message or "request created"
            extra:
                requestId: req.params.pushRequest?.requestId
                pushId: req.params.pushId

    @handleDispatchResult: (req, res, error) ->
    
        dispatch = req.params.dispatch

        if error
            # attach request params to error data
            error.params = req.params
            logger.info "push dispatch error", { error: Error.toJson(error) }
            
            jsonify res, error.status, { error: error.message }
        else
            if dispatch.response.statusCode is 200
                try
                    dispatch.requestId = JSON.parse(dispatch.body).request_id
                catch parseErr
                    logger.info "failed to parse request ID from upstream push response",
                        body: dispatch.body
                        error: Error.toJson parseErr
 
            logger.info "push request dispatched",
                pushId: req.params.pushId
                requestId: dispatch.requestId

            # respond with the upstream server response
            res.writeHead dispatch.response.statusCode, dispatch.response.headers
            res.end dispatch.body

        recordTiming req.app.statsd, "push.dispatch", req.params.start, error

        auditLogger.audit
            event: "push-dispatch"
            success: not error
            code: error?.status or dispatch.response.statusCode
            message: error?.message or "request dispatched"
            extra:
                requestId: dispatch.requestId
                pushId: req.params.pushId

    ###
    # handle app push request for a local connected client.
    ###
    @localPush: (req, next) ->

        async.waterfall [

            @validate(req),
            @createPushRequest(req),
            @sendPushRequestToWorker(req)

        ], next

    ###
    # handle forwarding app push request to a peer elephant server.
    ###
    @forwardPush: (req, serverId, next) ->

        req.params.dispatch = true
            
        if Dispatcher.isForwarded req
            return next Error.http 502, 'cannot forward push more than once'

        Dispatcher.dispatch req, serverId, (err, res, body) ->

            req.params.dispatch =
                response: res
                body: body
        
            next err

    ###
    # validate push request.
    ###
    @validate: (req) ->

        (next) =>
        
            async.waterfall [

                validate.isPost(req),
                validate.isJson(req),
                validate.acceptsJson(req),
                validate.validateAppBasicAuth(req),
                validate.parseJson(req),
                validate.validateRevokedPushId(req),
                @parsePushMessage(req)

            ], next

    ###
    # parse the push message from the request json body.
    ###
    @parsePushMessage: (req) ->

        (next) ->

            message = req.body.message
            if not message
                return next Error.http 400, "'message' field is missing"
            if message.length > MAX_FIELD_SIZE
                return next Error.http 400, "'message' field too long (>#{MAX_FIELD_SIZE})"

            req.params.message = message
    
            callback = req.body.callback
            if not callback
                return next null
            if not callback.url
                return next Error.http 400, "callback 'url' field is missing"

            parsedUrl = url.parse callback.url
            if parsedUrl.protocol not in ['http:', 'https:']
                return next Error.http 400, "malformed callback url"

            {username, password} = callback
            if username or password
                if not username or not password
                    return next Error.http 400, "callback 'username' or 'password' is missing"
                if parsedUrl.protocol isnt 'https:'
                    return next Error.http 400, "callback url must be HTTPS with username/password"
                if username.length > MAX_FIELD_SIZE or password.length > MAX_FIELD_SIZE
                    return next Error.http 400,
                        "callback 'username' or 'password' fields too long (>#{MAX_FIELD_SIZE})"

            req.params.callback = callback
            next null

    @getClientInfo: (req) ->

        (next) ->

            req.app.clientmap.getClient req.params.pushId, (err, client) ->

                if err
                    return next Error.http 500, "internal DB error", {}, err

                if not client
                    return next Error.http 404, "client not connected"

                req.params.client = client
                next null

    @dispatch: (req) ->

        (next) =>

            if req.params.client.serverId.indexOf(req.app.serverId) < 0
                # client connected to another host, forward the request
                @forwardPush req, req.params.client.serverId, next
            else
                # locally connected client, push
                @localPush req, next

    ###
    # save the push request to db.
    ###
    @createPushRequest: (req) ->

        (next) ->

            client = req.params.client
            callback = req.params.callback

            pushRequest = PushRequest.create
                clientId: client.clientId
                pushId: client.pushId
                serverId: client.serverId
                workerId: client.workerId
                callbackUrl: callback?.url
                callbackUsername: callback?.username
                callbackPassword: callback?.password

            req.app.pushRequestManager.addPushRequest pushRequest, (err, dbObj) ->
        
                if err
                    next Error.http 500, "failed to persist push request", {}, err
                else
                    logger.info "push request added",
                        pushId: dbObj.pushId
                        requestId: dbObj.requestId
                        pushIndex: dbObj.pushIndex

                    req.params.pushRequest = dbObj
                    next null

    ###
    # send push request to worker process where client is connected.
    ###
    @sendPushRequestToWorker: (req, res) ->

        (next) =>

            pushRequest = req.params.pushRequest
            message = req.params.message
    
            msg =
                head: 'SERVER_PUSH'
                clientId: pushRequest.clientId
                pushId: pushRequest.pushId
                pushIndex: pushRequest.pushIndex
                requestId: pushRequest.requestId
                data: message

            PoolLayer.sendMsgToWorker pushRequest.workerId, msg, (err) =>

                if err
                    logger.info "failed to send push request to worker",
                        workerId: pushRequest.workerId
                        pushId: pushRequest.pushId
                        requestId: pushRequest.requestId

                    # lazy removal of stale client entry from dead worker.
                    @deleteFromClientMap req.app, pushRequest.pushId

                    # push request was saved to db so we need to delete it.
                    @deletePushRequest req.app, pushRequest

                    next Error.http 404, "worker not found", {}, err
                else
                    next null

    ###
    # delete client entry from client map.
    ###
    @deleteFromClientMap: (app, pushId) ->

        logger.info "deleting client entry from client map",
            pushId: pushId

        app.clientmap.remove pushId, (err) ->

            if err
                logger.error "failed to delete client entry from client map",
                    pushId: pushId

    ###
    # delete push request from db.
    ###
    @deletePushRequest: (app, pushRequest) ->

        logger.info "deleting push request",
            pushId: pushRequest.pushId
            requestId: pushRequest.requestId
            
        app.pushRequestManager.deletePushRequestByIndex pushRequest.pushIndex, (err) ->

            if err
                logger.error "failed to delete push request",
                    pushId: pushRequest.pushId
                    requestId: pushRequest.requestId


module.exports = Push
