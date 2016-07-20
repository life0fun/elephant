#!/usr/bin/env coffee

#
# A wrapper layer on top of spdy protocol node module.
#

#
# using node-spdy, need to find out all components. on request (req, res)
# res is an outgoingMessage. only raw net.Socket is directly writable.
# req, res are incomingMessage or outgoingMessage.
#   socket = res.socket   # the same as res.socket and req.connection.socket
#
# Each stream is created when SYN_STREAM frame sent by either endpoint.
# [SYN_STREAM] ... [SYN_REPLY] ... [DATA]
#
# Each socket(res) has streams[].
#    for streamID in .streams streams[streamID].write(data, encoding)
#
# connection = res.socket.connection
# streams = res.socket.connection.streams
# stream = res.socket.connection.streams[streamID]  # arguments dict
# framer = res.socket.framer.dataFrame()
# headers = res.socket.headers
# frame = res.socket.frame.type
# parser = res.socket.parser  [ onBody, onMessageComplete ]

#
# Lesson learned: do not cache @res.socket with a local pointer !!!
# when socket got closed, @res.socket is null, socket object should be GCed.
# If you set pointer to it, you add a ref to socket object and GC wont be 
# able to free it. Worst, you cached a stale object, useless.
#

#
# When inside a stream, everything is data frame.
# To send ctrl frame, you need to send over @socket.connection.write
#

net = require('net')
util = require('util')
ElephantError = require('../common/error')
moment = require('moment')
Config = require('../config/config')

Logging = require('../common/logging')

#
# Each spdy handler abstract out a res.socket and all spdy components
# socket is actually the res of (req, res) pair.
#
# when sending control frame, send thru socket.connection.write()
# within the same stream, send data thru res writable IF.
#
class SpdyHandler

    logger = Logging.getLogger "spdyhandler"

    # socket is actually the res of (req, res) pair.
    # spdy handler is associated with a session in session map.
    # serverId and workerId are stored in session.
    constructor: (@req, @res) ->
        @buffer = new Buffer(0)


    # factory pattern
    # socket is actually the res of (req, res) pair.
    @create: (req, res) ->
        return new SpdyHandler req, res


    toString: ->
        "#{@res.socket.remoteAddress}:#{@res.socket.remotePort}"


    # return true if socket ip and port match
    isSpdyHandlerAddress: (ip, port) ->
        if @res.socket and @res.socket.remoteAddress is ip and   \
           @res.socket.remotePort is port
            return true
        return false

    
    # write head is wrapped into  syn replyFrame
    writeHead: (statuscode) ->
        @res.writeHead (statuscode)


    #
    # send syn reply, syn reply is control frame, still write to connection.
    #
    synReply: (data, cb) ->
        if not @res.socket or not @res.socket.writable
            return false

        replyframe = @framer.replyFrame @streamID, 200, 'more data', \
                                {"content-type" : "text/plain" }, \
                                (err, frame) =>
            @res.socket.connection.write frame
            if typeof cb is 'function'
                cb.call()

    #
    # send a data frame, dataFrame belongs to a stream, use stream
    # use this func causes header to be added.
    #
    sendDataFrame: (data, fin, cb) ->
        if not @res.socket or not @res.socket.writable
            return false

        buffer = null
        if typeof data is 'string'
            buffer = new Buffer(data)
        else
            buffer = data

        @logger.info 'sending data frame...', data
        df = @framer.dataFrame @streamID, fin, buffer
        @res.socket.lock =>
            @res.socket.connection.write df
            @res.socket.unlock()
        #@res.socket.connection.write df
        #@res.write df
        #@res.write 'write from res'

    #
    # When inside a stream, everything is data frame.
    # To send ctrl frame, you need to send over socket.connection,
    #
    sendRstFrame: ->
        if not @res.socket or not @res.socket.writable
            return false

        rst = @framer.rstFrame @frame.id, 1
        @logger.info 'sending rest frame: ', rst.type, rst.status
        @res.socket.connection.write rst

    #
    # send ping frame. When inside a stream, everything is data frame.
    #
    sendPingFrame: (pingIdNum) ->
        pf = @framer.pingFrame pingIdNum
        @res.socket.connection.write pf

    #
    # send raw string over the current stream.
    #
    sendStreamData: (data) ->
        if not @res.socket or not @res.socket.writable
            return false

        @logger.info 'sending data over stream : ', data
        # always remember to write header to any data frame
        @res.writeHead 200, {'Content-Length' :  data.length}
        @res.write data

        # if server send data over a particular stream
        #@req.connection.connection.streams[1].write 'xxx', 'utf-8'
        #@stream.write data, 'utf-8'

        # if you send thru stream, must be a frame
        #@res.connection.write 'hellow orld ', 'utf-8'
        #@stream.end 'hello world end ', 'utf-8'
        #spdy.utils.zstream @stream,  data, () ->
        #   Node.log ' sending thru streams done...'

    ###
    # upon server push, spdy create a new stream with even num stream id.
    # with frame type SYN_FRAME  and return the stream object.
    # Socket.id = streamID will be the corrId for the server push frame.
    # we close the stream after done. Client spdylay also closed its ack stream.
    ###
    serverPush: (msg, callback) ->
    
        if not @res.socket or not @res.socket.writable
            return callback Error.http 404, 'socket is not writeable'
    
        logger.debug "server push", { client: @toString() }

        # use spdy push api to push data object json string to client
        url = Config.getConfig "SERVER_PUSH_URL"

        pushData = JSON.stringify
            request_id: msg.requestId
            data: msg.data

        headers =
            "Content-Type": "application/json"
            "Content-Length": pushData.length

        @res.push url, headers, (err, stream) ->

            if err
                return callback Error.http 404, "stream push error", {}, err

            stream.on 'error', (err) ->
                stream.close()
                callback Error.http 404, "spdy stream push error", {}, err

            stream.once 'finish', ->
                stream.close()
                callback null

            stream.end pushData


exports.SpdyHandler = SpdyHandler
