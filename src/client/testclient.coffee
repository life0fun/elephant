#!/usr/bin/env coffee
#

#
# testclient wraps netclient, which uses net.socket to net.socket server.
#
net = require 'net'
util = require 'util'
cluster = require 'cluster'
spdyclient = require('spdyclient').Client
cpus = require('os').cpus().length
EventEmitter = require('events').EventEmitter

# a test client that creates tons of netclient and make persistent tcp conns
# with raw socket. protocol between client and server is defined
#
class Node extends EventEmitter
    constructor: (@client) ->

    @log: (msg, extra...) ->
        console.log msg, extra...

# one test client for one cpu
class TestClient extends Node
    # class static constant
    MAX_CONNECTIONS = 1000000  # lets scale to 1m connections
    connMap = [0..MAX_CONNECTIONS]
    freeHead = undefined

    constructor: (name, numconns, host, port) ->
        @name = name || 'testclient'
        @numconns = numconns || 10      # default 10 conns
        @host = host || 'localhost'
        @port = port || 9433
        @clients = []
        # tested with 1m connections
        #TestClient.initConnection(List)
        @initRequestClients @numconns
        @numclients = numconns

    @createTestClient : (name, numconns, host, port) ->
        return new TestClient(name, numconns, host, port)

    # alloc 1m connections linked list with each node denotes a connection
    @initConnectionList: () ->
        for i in [0..MAX_CONNECTIONS]
            console.log cluster.worker.id, i, ' init one connection...', i
            pcur = {}
            connMap[i] = pcur
            connMap[i].id = i
            if typeof freeHead == 'undefined'
                pcur.next = pcur.prev = freeHead = pcur
            else
                pcur.next = freeHead
                pcur.prev = freeHead.prev
                freeHead.prev.next = pcur
                freeHead.prev = pcur

    # each TestClient runs in one CPU. init http request data struct
    initRequestClients: (num) ->
        options = {}
        if process.env.NODE_ENV is 'test'
            options.host = 'localhost'
            options.port = 9080
        else
            options.host = 'localhost'
            options.port = 9443
        options.method = 'GET'
        # each connection = a client
        for i in [0..num-1]
            options['name'] = this.name + '-client-'+i
            options.path = '/client/v2/puid-'+i
            @clients[i] = spdyclient.createClient(options)

    startTesting : () ->
        console.log @numclients
        for i in [0..@numclients-1]
            msg = this.clients[i].makeBody()
            #Node.log 'sending request:', msg
            #this.clients[i].clientreq.write msg

exports.TestClient = TestClient

#
# unit testing
unittest = (num) ->
    if cluster.isMaster
        #require('os').cpus().forEach () ->
        for i in [0..cpus-1]
            console.log 'forking one cpu....'
            cluster.fork()

        # re-start the worker once it dies
        cluster.on 'death', (worker) ->
            console.log 'worker dead...' + worker.pid
            cluster.fork()
    else
        console.log 'num clients : ' + num
        testclient = TestClient.createTestClient(cluster.worker.id, num)
        testclient.startTesting()

unittestMono = (num) ->
    console.log 'num clients : ' + num
    testclient = TestClient.createTestClient(0, num)
    testclient.startTesting()

num = process.argv[2] || 100
unittestMono(num)

#
#after connecting to server, client is looping
#
