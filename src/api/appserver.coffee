#!/usr/bin/env coffee

#
# App server to handle App request from sparkle
# This server is running on master only. It send app client api msg
# to individual workers, which are running inside standalone process.
#
# From worker to master, just do process.send({}). it sends object itself.
#


# use webkit node-webkit-agent
agent = require('webkit-devtools-agent')


http = require 'http'
https = require 'https'
fs = require 'fs'
moment = require('moment')

Logging = require('../common/logging')
Config = require('../config/config')
Router = require('../router/router').Router
{Client, ClientMap} = require('../model/clientmap')
{PushRequestManager} = require('../model/pushrequest')  # active push list
PoolLayer = require('../pool/poollayer')
statsd = require('../metrics/statsd')

pushV2 = require('./app/v2/push')
admin = require('./admin/v1/admin')

# global settings to increase agent pool
require('http').globalAgent.maxSockets = Config.getConfig 'MAX_SOCKETS'


class AppServer
    # class static logger
    logger = Logging.getLogger "appserver"
    auditLogger = Logging.getAuditLogger "accounting"

    constructor: (@options) ->

        @serverId = @options.serverId

        # we are using https
        keys = Config.getConfig 'KEYS'
        httpsOptions =
            key: fs.readFileSync keys.key
            cert: fs.readFileSync keys.cert

        @httpsServer = https.createServer httpsOptions, @onRequest
        @httpsServer.listen @options.app_port

        logger.silly "App server listening on #{@serverId}"

        # create the router
        @router = Router.create(this)
        @bindRouteHandler()

        # create client map with empty option for now
        @clientmap = ClientMap.create @options

        # create push request manager with options
        @pushRequestManager = PushRequestManager.create options

        @setupWorkerMsgProcessor()

        @blacklist = @options.blacklist
        @statsd = statsd.getClient()

        logger.info " >>> Elephant App server started ! <<< "

    @createServer: (options) ->
        return new AppServer options

    # callback handler, fat binding.
    onRequest: (req, res) =>
        # route the req for normal https request
        @router.route(req, res)

    ###
    # generic route setup.
    #
    # @param {Function} handler - route handler.
    ###
    route: (handler) ->

        (req, res) =>

            # initialize request properties
            req.app = @

            handler req, res
    
    # bind all router handlers
    # url must not end with / in order to match
    bindRouteHandler: ->
        @bindApplicationRoutes()
        @bindAdminRoutes()

    # bind all application routes
    bindApplicationRoutes: ->
        @router.handleAll Router.pushRouteV2(), @route pushV2.handle

    # bind all admin routes
    bindAdminRoutes: ->
        @router.handleAll '/admin/v1/client/{pushId}', @route admin.getClient
    
        if Config.getConfig 'REVOKE_API_ENABLED'
            @bindRevokeRoutes()

    # bind all revoke admin routes
    bindRevokeRoutes: ->
        # revoke a client id, debug and unit test
        @router.handleAll '/admin/v1/revokedClientId', @route admin.revokeClientId

        # revoke a push id and client id, debug and unit test
        @router.handleAll '/admin/v1/revokedPushId', @route admin.revokePushId

    # master handle worker msg about client add/del from each individual worker
    handleWorkerMessage: (workerId, msg) =>
        @msgProcessor[msg.head].call(this, workerId, msg)

    # add a client, serverId and worker Id is provided.
    addToClientMap: (pushId, clientId, serverId, workerId, onAdded) ->
        @clientmap.add pushId, clientId, serverId, workerId, onAdded

    # del a client from client Map
    delFromClientMap: (pushId, onDeleted) =>
        @clientmap.remove pushId, onDeleted

    # update client map, with clientid and value object
    updateClientMap: (clientId, valueObj, onUpdated) ->
        @clientmap.update clientId, valueObj, onUpdated

    ###
    # setup processor to handle worker msg in table driven manner
    # state machine with table driven. Following is a list of message handlers.
    ###
    setupWorkerMsgProcessor: ->
        @msgProcessor =
            'WORKER_READY' : @processWorkerReady.bind(this)
            'ADD_CLIENT' : @processAddClient.bind(this)
            'DEL_CLIENT' : @processDelClient.bind(this)
            'UPDATE_CLIENT' : @processUpdateClient.bind(this)

    # proces worker ready msg, notify parent
    processWorkerReady: (workerId, msg) ->
        logger.info 'worker ready', worker: msg.workerId
        @options.notifyParent.emit 'success', msg.workerId

    # process add client, add to map
    processAddClient: (workerId, msg) ->
        logger.info "master process adding client to client map",
            pushId: msg.pushId
            serverId: msg.serverId
            workerId: msg.workerId

        dbError = (err, result) ->
            if err
                logger.error 'add to client map :', err
                # TODO if we cannot add a connected clients to database,
                # that means the system shall not accept any connections at
                # this point, until db is insertable. what we do now ?
                # disconnect the client to let it retry, or...

            auditLogger.audit {
                event: "client-added"
                success: not err
                message: err?.toString() or "client added to map"
                extra:
                    clientId: msg.clientId
                    pushId: msg.pushId
            }

        # add primitive id strings to map
        @addToClientMap msg.pushId, msg.clientId,
                        msg.serverId, msg.workerId,
                        dbError

    # process del client, rm from map, clean up
    processDelClient: (workerId, msg) ->
        logger.info "client disconnected from worker",
            workerId: workerId
            pushId: msg.pushId

        @delFromClientMap msg.pushId, (err, result) ->
            logger.error "process delete client err #{err}" if err

            auditLogger.audit {
                event: "client-removed"
                success: not err
                message: err?.toString() or "client removed from map"
                extra:
                    pushId: msg.pushId
            }

    # process update client, update push id in map
    processUpdateClient: (workerId, msg) ->
        logger.info "master update client in client map",
            workerId: msg.workerId
            pushId: msg.pushId

        valueObj =
            clientId: msg.clientId
            pushId: msg.pushId

        @updateClientMap msg.clientId, valueObj, (err, result) =>
            logger.info 'update client map :', err if err

            auditLogger.audit {
                event: "client-updated"
                success: not err
                message: err?.toString() or "client updated in map"
                extra:
                    pushId: msg.pushId
            }
    
    
exports.AppServer = AppServer
