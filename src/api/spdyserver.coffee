#!/usr/bin/env coffee

#
# A spdy server for persistent connections
#

#
# Node cluster:
# for master to send msg to worker
#   cluster.worker[i].send(msg, [sender handler])
# Worker will get on 'message' event.
#
# From worker to master, just do process.send({}).
# it sends object, not the string.
#

#
# using node-spdy, need to find out all components. on request (req, res)
# res is an outgoingMessage. only raw net.Socket is directly writable.
# req, res are incomingMessage or outgoingMessage.
#
# socket is shared among all spdy request streams in the same session.
# socket is created upon SecureConnection. so Server.connection.socket
#
# Following reqs in the same connection socket session
# wrapped into each req object's socket.
#
# For each spdy req, req.socket = res.socket have parsed data.
# req.connection.socket = server session socket have data frame.
#
# when handle socket event, do it on req.connection.socket.
# when handle data, do it on req.socket = res.socket.
#
# All socket.remotePort/remoteAddress are the same !
#
# req.socket = res.socket on data.
# connection = server.connection = req.res.socket.connection
# parser = server.connection.parser
# streams = server.connection.streams
# stream = server.connection.streams[streamID] # arguments dict
# framer = server.connection.parser.framer
# headers = res.socket.headers
#

# For incoming streamID, take it from req.socket
#   req.streamID = res.streamID = req.socket.id
# For outgoing stream id, take server.connection.pushId


# when using session.send, it send data frame thru the original stream.
# use res.end to send data frame thru this req/res stream and close it.
# always use req/res stream, which is opened in the current request.
# only use session.send when you want to push data.

# you can disable profiling and dump everything to stdout
#nodetime = require('nodetime').profile({stdout:true})

spdy = require 'spdy'
net = require 'net'
util = require 'util'
http = require 'http'
https = require 'https'
tls = require 'tls'
fs = require 'fs'

Logging = require('../common/logging')
ElephantError = require('../common/error')

{Session, SessionManager} = require('../model/session')
Router = require('../router/router').Router
PoolLayer = require('../pool/poollayer')
statsd = require('../metrics/statsd')
{PushRequestManager} = require('../model/pushrequest')
Config = require('../config/config')

registerV2 = require('./v2/register')
refreshV2 = require('./v2/refresh')
listenV2 = require('./v2/listen')
ackV2 = require('./v2/ack')

SendPush = require('../push/send')

FileStream = require('../common/filestream').FileStream

# global settings to increase agent pool
require('http').globalAgent.maxSockets = Config.getConfig 'MAX_SOCKETS'

# ------------------------------------------------------------
# start of SPDY server
# ------------------------------------------------------------
class SpdyServer
    logger = Logging.getLogger "spdyserver"
    auditLogger = Logging.getAuditLogger "accounting"

    constructor: (@name, @options) ->
        logger.debug "Spdy server running on port #{@options.spdy_port}"

        keys = Config.getConfig 'KEYS'
        tlsOptions =
            key: fs.readFileSync keys.key
            cert: fs.readFileSync keys.cert

        @server = spdy.createServer(tlsOptions, @onRequest).listen(@options.spdy_port)
        @server.on 'connect', (req, res) ->
            logger.debug "spdy client connected..."


        @server.on 'secureConnection', (socket) ->
            logger.debug 'server on SecureConnection :',
                          socket.remotePort, socket.remoteAddress

        # Note that each worker in the cluster is running this server !!!
        # serverId uses server ip address and spdy port.
        @workerId = PoolLayer.getWorkerId()
        @workerName = PoolLayer.getWorkerName()
        @serverId = PoolLayer.getServerAddress()

        @sessionManager = SessionManager.create @options
        @blacklist = @options.blacklist
        @pushRequestManager = PushRequestManager.create @options
        @statsd = statsd.getClient()
    
        # create the router
        @router = Router.create(this)
        @bindRouteHandler()

        # push to client handler
        @sendPush = SendPush.create @
    
        @setupMasterMsgProcessor()

        msg =
            head: 'WORKER_READY'
            serverId: @serverId
            workerId: @workerId

        PoolLayer.sendMsgToMaster msg

        @reportConnectedClients()

        logger.info ' >>>>> Elephant Spdy Server started ! <<<<< ', { workerId: @workerId }

    # factory pattern
    @createServer: (options) ->
        return new SpdyServer('SpdyServer', options)     # no options for now

    # callback upon connection comes in
    onRequest: (req, res) =>
        @router.route(req, res)

    ###
    # bind route handlers.
    # order matters since listen route clobbers all.
    ###
    bindRouteHandler: ->
        # add ack api
        @router.handleAll Router.ackRouteV2(), @route ackV2.handle

        # add refresh api
        @router.handleAll Router.refreshRouteV2(), @route refreshV2.handle

        # add register api
        @router.handleAll Router.registerRouteV2(), @route registerV2.handle

        # listen api needs to be the last route matched due to its
        # catchall route mapping.
        @router.handleAll Router.listenRouteV2(), @route listenV2.handle

        @router.handleGet '/profile', @handleProfile.bind(this)

    ###
    # generic route setup.
    #
    # @param {Function} handler - route handler.
    ###
    route: (handler) ->

        (req, res) =>

            # initialize request properties
            req.params ?= {}
            req.app = @

            handler req, res
    
    ###
    # setup master msg processor to handle command from master
    # state machine pattern to avoid ugly if else switches.
    ###
    setupMasterMsgProcessor: ->
        @masterMsgProcessor =
            'SERVER_PUSH': (msg) => @sendPush.handle msg

    ###
    # handle msg from app server to master to worker.
    # table driven state machine.
    ###
    handleMasterMessage: (msg) ->
        @masterMsgProcessor[msg.head] msg

    ###
    # update statsd with number of connected clients.
    # @param duration - client's connection duration in milliseconds. optional.
    ###
    reportConnectedClients: (duration) ->
        @statsd.gauge "worker_#{@workerName}.clients.connected",
                         @sessionManager.getLength()
        if duration
            @statsd.timing "worker_#{@workerName}.clients.duration", duration


    toString: ->
        return PoolLayer.toString()

    # trigger heap dump to get mem profile
    handleProfile: (req, res) ->
        if Config.getConfig 'MEM_WATCH'
            memprof = require('../common/memprof').MemProf.create this
            memprof.toggleHeapDump()
        res.end(200)


exports.SpdyServer = SpdyServer

# ------------------------------------------------------------
# end of SPDY server
# ------------------------------------------------------------
