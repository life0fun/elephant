#!/usr/bin/env coffee

#
#
# Session manages all sessions on top of socket connection
# socket address+port is used to uniquely identify each session
# to send msg through session, there are 3 cases:
#  1. if socket is raw socket create by net.createConnection(),
#       then you can write to it direct.
#  2. if socket is a underneath a stream, then you need to write to stream,
#      not to socket directly.
#     http req/res object req.socket = res.socket = req.connection.socket
#  3. the same for spdy stream that wrapped with SYN_STREAM and SYN_REPLY
#
# Session Manage uses clientId as index, as oppose to clientMap uses pushId.
#

net = require('net')
util = require('util')

Logging = require('../common/logging')
ElephantError = require('../common/error')
helper = require('../common/helper')

#
# Each session only knows the dumb buffer.
# the data processing logic should be exposed to upper layer
#
class Session
    # class static logger
    logger = Logging.getLogger "session"

    constructor: (options) ->
        @options = helper.copyObjectPrimitives(options)
        @sequence = 0
        @buffer = new Buffer(0)
        @msgcounts = 0
        @startTime = Date.now()

        # when socket close, socket props turned to undefined
        # remoteport and adddress stored in spdyhandler

        # stream is outgoing Message, incoming is req.on data
        @stream = options.stream   # client info stream is @res

        @isSpdy = options.isSpdy || false
        @clientId = options.clientId
        @pushId = options.pushId
        @serverId = options.serverId
        @workerId = options.workerId
        @pushTransId = 0   # number of pushes to this client
        @pushTimers = {}
        # each spdy client has a spdyhandler, created inside Listen api handler
        @spdyHandler = options.spdyHandler || undefined

    # factory pattern
    @createSession: (options) ->
        return new Session options

    toString: ->
        return "session : #{@pushId} #{@serverId} #{@workerId}"

    getPushTimer: (requestId) ->
    
        @pushTimers[requestId]

    addPushTimer: (requestId, timer) ->
    
        @pushTimers[requestId] = timer

    removePushTimer: (requestId) ->

        if not requestId of @pushTimers
            return false

        delete @pushTimers[requestId]
        return true

    # update session's pushId
    updatePushId: (pushId) ->
        @pushId = pushId

    # update the last seen timestamp on session
    updateLastSeenPing: (pingId) ->
        @spdyHandler.updateLastSeenPing pingId

    # send data thru stream, valid for spdy stream. non-spdy is for testing only.
    send: (data, onSent) ->
        if not @stream.writable
            return false

        if @isSpdy
            logger.debug data, 'session.send.spdyHandler >> ', @toString()
            @spdyHandler.sendStreamData data
            if typeof onSent is 'function'
                onSent()
        else
            logger.debug data, 'session.send.http.stream >> ', @toString()
            @stream.writeHead 200
            @stream.write data, onSent
        return true

    ###
    # send server push message to spdy client.
    #
    # @param msg - push message options.
    ###
    serverPush : (msg, onPushDone) ->
        if @isSpdy
            logger.debug 'spdy push', { session: @toString() }
            @spdyHandler.serverPush msg, onPushDone
        else
            onPushDone Error.http 500, 'client does not support push'

    # close a stream connection
    close: ->
        @stream.end()

    # handle chunk data
    getChunkData : (chunk, onGetData) ->
        # buffer append: new Buffer, copy existing, append chunk
        # discard the old buffer
        @buffer = new Buffer(0)
        oldBuffer = @buffer
        @buffer = new Buffer oldBuffer.length + chunk.length
        oldBuffer.copy @buffer
        chunk.copy @buffer, oldBuffer.length
        logger.debug ' data :' + @buffer.toString()
        onGetData @buffer.toString()

#
# Session Manager manage all sessions for server
# this is session controller, or mediator pattern.
#
class SessionManager
    # class static logger
    logger = Logging.getLogger "session"

    constructor: (options) ->
        
        @options = options || {}
        @sessions = []    # array of all client sessions
        @sessionMap = {}  # object map, session id by clientId
        @numSessions = 0

    # factory pattern
    @create : (options) ->
        return new SessionManager options

    # dump all the sessions
    dumpSessions: () ->
        if @numSessions > 0
            for s in @sessionMap
                s.toString()

    # check whether session about cientId exist
    hasSession: (clientId) ->
        return @sessionMap.hasOwnProperty(clientId)

    getLength: ->
        return @numSessions

    # when client dies, session will be delete, caller need to be careful !
    getSession: (clientId) ->
        session = @sessionMap[clientId]
        if not session
            logger.error 'get session : no session for :', clientId
        return session

    ###
    # delete a session using clientId, return session duration.
    # @param clientId client id of the session. when socket is invalid, we only know clientId
    # @return session duration in seconds if session is valid. -1 otherwise
    ###
    deleteSession: (clientId) ->
        dur = 0
        client = @getSession clientId
        if client
            # start time initialized inside constructor
            dur = Date.now() - client.startTime
            delete @sessionMap[clientId]
            @numSessions -= 1
            logger.info "sessionManager delete #{clientId} dur #{dur} tot #{@numSessions}"
            return dur/1000    # convert to seconds
        else
            return -1

    # create a new session and add to session manager
    # no client name yet, update client
    addSession: (options) ->
        session = Session.createSession options
        @numSessions += 1 if not @hasSession(session.clientId)
        @sessionMap[session.clientId] = session
        logger.info 'sessionMan add :', session.toString(), 'tot:', @numSessions

        return session

    # update client name in each session, upon a new msg from client
    updateSessionClient : (ip, port, name) ->
        session = @getSession ip, port
        if session
            logger.info 'update session : ', name, session.spdyHandler.remotePort

    # senssion manager bcast msg
    bcastPush : (msg) ->
        for s in @sessions
            s.send 'bcastPus >> ' +  s.clientId + ' : ' + msg

    # send msg to client with pushId
    pushMsgToClient : (clientId, transId, msg, onPushDone) ->
        session = @getSession clientId
        if session
            session.serverPush transId, msg, onPushDone
        else
            e = ElephantError.create(ElephantError.CLIENT_SESSION_NOT_EXIST, \
                                     'client_id:'+ clientId + \
                                     ' push_id ' + pushId   + \
                                     ' session.coffee', 'sendMsgByPushId')
            onPushDone(404, e)   # session not found, lost connection, clean up

    # send msg to client session idx
    sendMsg : (idx, msg, onSent) ->
        session = @sessions[idx]
        session.send msg
        onSent ' '

exports.Session = Session
exports.SessionManager = SessionManager

# unit test
#option = {host:'localhost', port:3000}
#cli_session = Session.createSession(option)

