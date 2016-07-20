#!/usr/bin/env coffee

#
# https handler inside spdy server
#

#
#

net = require('net')
util = require('util')
url = require('url')

handler = require('./handler')
ReqBuffer = require('./reqbuffer').ReqBuffer

#
# Each spdy handler abstract out a res.socket and all spdy components
# socket is actually the res of (req, res) pair.
#
# when sending control frame, send thru socket.connection.write()
# within the same stream, send data thru res writable IF.
#
class HttpsHandler
    constructor : (@req, @res, @clientId, @spdyServer) ->
        # only raw net.Socket is directly writable.
        # ip:port is the same as req.connection.socket
        # data structure wise, it is not the same.
        @socket = res.socket
        @socket.setNoDelay(true)   # only set socket options for raw net.Socket
        @socket.setTimeout(0)

        @reqBuffer = ReqBuffer.create @req, @clientId, @onData

        @reqpath = url.parse req.url, true

    # factory pattern
    @create : (req, res, clientId, spdyserver) ->
        return new HttpsHandler req, res, clientId, spdyserver

    # on data handler
    onData : (data) =>
        handler.processMessage data, (respobj) =>
            console.log 'HTTPS client :', @clientId, JSON.stringify(respobj)


exports.HttpsHandler = HttpsHandler

# unit test
# httpsHandler = HttpsHandler.create req, res, server

