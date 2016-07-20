#
# Listen V2 Api request handler.
#

async = require('async')
url = require('url')

Config = require('../../config/config')
Logging = require('../../common/logging')
validate = require('../../common/validate')
{jsonify, recordTiming} = require('../../common/request')
{PushId} = require('../../model/clientpushid')
PoolLayer = require('../../pool/poollayer')
{SpdyHandler} = require('../spdyhandler')


###
# Listen request handling.
###
class Listen

    logger = Logging.getLogger "listen-v2"
    auditLogger = Logging.getAuditLogger "accounting"

    ###
    # validate listen request.
    ###
    @validate: (req) ->

        (next) =>

            async.waterfall [

                validate.isSpdy(req),
                validate.isGet(req),
                validate.acceptsJson(req),
                validate.parseClientId(req),
                validate.validateRevokedClientId(req),
                validate.validatePushId(req),
                validate.validateRevokedPushId(req),
                @validateMinPingInterval(req),

            ], next

    @validateMinPingInterval: (req) ->

        (next) ->

            query = url.parse(req.url,true).query

            if not query.min_ping_interval_sec
                next Error.http 400, "min_ping_interval_sec is required."

            minPingIntervalSec = Number(query.min_ping_interval_sec)

            if minPingIntervalSec <= 0 or Number.isNaN(minPingIntervalSec)
                next Error.http 400, "min_ping_interval_sec must be a positive number."
            else
                req.params.minPingIntervalSec = minPingIntervalSec
                next null

    ###
    # create clientInfo wrapper object.
    ###
    @createClientInfo: (req, res) ->

        (next) ->

            spdyHandler = if req.isSpdy then SpdyHandler.create(req, res) else null

            req.params.clientInfo =
                clientId: req.params.clientId
                isSpdy: req.isSpdy
                pushId: req.params.pushId
                serverId: PoolLayer.getServerAddress()
                spdyHandler: spdyHandler
                stream: res
                workerId: PoolLayer.getWorkerId()

            next null

    ###
    # notify master about client when adding a new client.
    ###
    @notifyMasterAddClient: (req) ->

        (next) ->

            msg =
                head: "ADD_CLIENT"
                clientId: req.params.clientInfo.clientId
                pushId: req.params.clientInfo.pushId
                serverId: req.params.clientInfo.serverId
                workerId: req.params.clientInfo.workerId

            logger.debug "notify master on add client", msg

            PoolLayer.sendMsgToMaster msg
            req.app.reportConnectedClients()

            next null

    ###
    # clean up everything upon socket close, and socket error, avoid Mem leak.
    ###
    @setReqSocketCloseHandler: (req, res) =>

        self = @

        (next) ->

            sessionManager = req.app.sessionManager
            session = req.params.session

            req.connection.socket.once 'error', (err) ->
                logger.info "socket error",
                    pushId: session.pushId
                    error: Error.toJson err
    
            req.connection.socket.once 'close', (had_error) ->
                logger.info "socket closed",
                    pushId: session.pushId
                    had_error: had_error
                duration = sessionManager.deleteSession session.clientId
                self._notifyMasterDelClient session.clientId, session.pushId, req.app, duration
                res.end()

            next null

    ###
    # notify master to del a client
    ###
    @_notifyMasterDelClient: (clientId, pushId, app, duration) ->

        msg =
            head: 'DEL_CLIENT'
            clientId: clientId
            pushId: pushId

        PoolLayer.sendMsgToMaster msg
        app.reportConnectedClients duration

    ###
    # set socket timeout.
    ###
    @_setSocketTimeout: (req) ->

        # minimum allowable socket timeout.
        minSocketTimeoutSec = Config.getConfig 'MIN_SOCKET_TIMEOUT_SEC'
        
        # Server defaults to timeout twice the client min ping interval.
        socketTimeoutSec = Math.max minSocketTimeoutSec, req.params.minPingIntervalSec * 2

        req.connection.socket.setTimeout (socketTimeoutSec * 1000)
        logger.debug "Setting socket timeout", {
            "pushId": req.params.pushId
            "timeoutSec": socketTimeoutSec
        }

        # Add the pingInterval to the request
        req.params.pingIntervalSec = socketTimeoutSec / 2
        

    ###
    # create client session.
    ###
    @createSession: (req, res) ->

        (next) =>

            sessionManager = req.app.sessionManager

            clientInfo = req.params.clientInfo
            req.params.session = sessionManager.addSession clientInfo

            # set props on secure connection's raw server.connection.socket
            req.connection.socket.setNoDelay true
            
            @_setSocketTimeout(req)

            next null

    ###
    # Sends back a x-elephant-config-json response
    #
    # IMPORTANT: it does not call response.end intentionally
    # leaving the connection open.
    ###
    @configify = (res, status, json) ->
        jsonStr = JSON.stringify json
        res.writeHead status, {
            "Content-Type": "application/x-elephant-config-json",
            "Content-Length": jsonStr.length
        }
        res.write(jsonStr)

    ###
    # handle client listen request.
    ###
    @handle: (req, res) =>
        
        self = @
        start = Date.now()

        async.waterfall [

            @validate(req),
            @createClientInfo(req, res),
            @createSession(req, res),
            @notifyMasterAddClient(req),
            @setReqSocketCloseHandler(req, res)

        ], (error) ->

            if error
                # attach request params to error data
                error.params = req.params

                logger.info "client listen error", { error: Error.toJson(error) }
                jsonify res, error.status, { error: error.message }
            else
                retryPolicy = Config.getConfig 'RETRY_POLICY'
                data =
                    reconnect_retry_policy: retryPolicy
                    pingIntervalSec: req.params.pingIntervalSec

                logger.info "Listen request initialized", { "pushId": req.params.session.pushId }

                self.configify res, 200, data

            recordTiming req.app.statsd, "listen", start, error

            auditLogger.audit {
                event: "listen"
                success: not error
                code: error?.status or 200
                message: error?.message or ""
                extra: {
                    pushId: req.params.session?.pushId
                }
            }


module.exports = Listen
