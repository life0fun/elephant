#!/usr/bin/env coffee

#
# client makes connection to server, send hello, then wait
# for server push message
#

net = require('net')
util = require('util')
url = require('url')
http = require('http')
https = require('https')
tls = require('tls')
cluster = require('cluster')
fs = require('fs')
cpus = require('os').cpus().length
assert = require 'assert'

# global settings to increase agent pool
require('http').globalAgent.maxSockets = 1000000

class Node
    constructor: (@options) ->

    @log : (msg, extra...) ->
        console.log msg, extra...


# each client instance is a http connection
class Client extends Node
    # once client object created, it creates connection to the server.
    constructor: (options) ->
        @sessions = []    # tcp session from client
        @sequence = 0
        @name = options.name || 'test-client'

        #@agent = new http.Agent()
        #@agent.maxSockets = 1000000  # 1 million connections
        @options = {
            host: 'localhost',   # will be overwrite from passed on options
            #host: 'elephant-dev.colorcloud.com',
            port: 9443,
            path: '/',
            method: 'POST',   # needs to be post to keep alive connection
            #agent: @agent,
            agent: false,
            requestCert: false,
            rejectUnauthorized: false,
            headers: {
                'connection' : 'keep-alive'
                #'Content-Type' : 'text/plain',
                #'Content-Length' : 10
            }
        }

        # combine all options, will overwrite host and port if passed in
        for k of options
            @options[k] = options[k]
            id = options.path.split('-')[1]
            @options.headers['authorization'] = 'Basic :clid-' + id
            @options.headers['accept'] = 'text/plain'

        #
        # this section create different type of connections to server
        #
        # create client http request inside constructor
        # https.request creates a net.Socket on server
        @clientreq = @createClientRequest @options
        #@tlssocket = @createTlsConnect(@options)
        #@clientreq = @createHttpRequest(@options)

    # factory pattern
    @createClient : (options) ->
        return new Client(options)

    # connect to server, only socket connection needs connect
    connect : (name, host, port) ->
        Node.log 'connecting to server...', host, ':', port
        opt = {clientname: name, host: host || 'localhost', port: port || 443}
        return Session.createSession opt

    # client sends data
    post: (data, cb) ->
        @res.write data, cb
        #@session.send data, cb

    # cook up msg to send to server
    makeBody : () ->
        msg = {}
        msg.name = @name   # always have the name prop, server deps on this
        msg.sequence = @sequence++
        msg.message = ' server, are you ok ? from client :' + @name
        return JSON.stringify(msg)

    # send one json request
    oneRequest: (clientreq) ->
        body = @makeBody()
        #Node.log ' send data:' + body
        clientreq.write body
        #clientreq.write '\\A'   # delimiter
        #@clientreq[i].end()   # no end, keep concurrent


    # create many client http requests
    # this version, need req.end() for request to make to the server
    createClientRequest : (options) ->
        Node.log 'creating client request...', JSON.stringify(options)

        # append cert key, cert cert, and cert ca
        #for k of keys
        #    options[k] = keys[k]

        #stream = tls.connect 3000, options, () =>
        #    body = @makeBody()
        #    Node.log 'tls connected to server: writing data :' + body
        #    stream.write(body)
        #
        #stream.on 'secureConnect', () ->
        #    Node.log 'tls secureconnected...'
        #stream.on 'authorizationError', (e) ->
        #    Node.log 'tls secureconnected...' + e

        # with http.request, one must always call req.end()
        clientreq = https.request options, (res) =>
            res.on 'data', (chunk) =>
                Node.log 'server data: ', chunk.toString() + ' >> ' + @name

            res.on 'close', () ->
                Node.log 'server closed connection...'

        clientreq.on 'connect', (res, socket, head) =>
            Node.log 'client connected....', @name
            @oneRequest(clientreq)

        clientreq.on 'error', (e) ->
            Node.log 'server error...:', e

        clientreq.setNoDelay()
        #clientreq.end(@makeBody())  # http.request requires call end()
        # should wait for connected event...but http request wait for end
        @oneRequest(clientreq)
        return clientreq

    # create a http request with another format
    # this one is not working...no event
    createHttpRequest : (options) ->
        Node.log 'creating http request....: ' + options.host
        clientreq = http.request options

        clientreq.on 'upgrade', (res, socket, head) ->
            Node.log 'upgrade called....'

        # this deps on connect event, which might never trigger
        clientreq.on 'connect', (res, socket, head) ->
            Node.log 'http request connected to server...write data !'
            socket.write('GET / HTTP/1.1\r\n' +
                          'Host: localhost:9080\r\n' +
                          'Connection: keep-alive\r\n' + '\r\n')

            socket.on 'data', (chunk) ->
                Node.log 'http request : socket data:' + chunk.toString()
            socket.on 'end', () ->
                Node.log 'server  ended...'

            res.on 'data', (chunk) =>
                Node.log 'server data: ', @name, ' << ', chunk.toString()

            res.on 'close', () ->
                Node.log 'http request : server closed connection...'

        clientreq.end()  # call end() to flush request

    #
    # create tls connections to tls server, or spdy server
    #
    createTlsConnect : (options) ->
        # add spdy/2 NPN protocol
        options['NPNProtocols'] = [ 'spdy/2' ]

        tlssocket = tls.connect options, () ->
            Node.log 'TLS connected...'

            if tlssocket.authorized
                Node.log 'TLS socket authorized....'
            else
                Node.log 'TLS socket failed auth:', tlssocket.authorizationError

            tlssocket.on 'data', (chunk)->
                Node.log 'TLS server push: ', chunk.toString(), ' >> ',  @name

            tlssocket.on 'close', () ->
                Node.log 'tls socket closed...'


        tlssocket.setNoDelay()
        @oneRequest(tlssocket)
        return tlssocket

exports.Client = Client

# unit test
unittest = () ->
    options = {}
    options.name = 'test-client'
    options['host'] = 'localhost'
    options['port'] = 9080

    Node.log 'client start unitesting'

    client = Client.createClient options
    #client.send client.makeMessage()

#unittest()
# after connecting to server, client is looping
