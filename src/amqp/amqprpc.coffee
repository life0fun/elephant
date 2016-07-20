#!/usr/bin/env coffee

#
# node amqp rpc client that interacts with rabbitMQ to
# perform RPC calls in distributed environments.
#
# rpc means client create a callback reply Q and subscribe to it
# client send task to server's Q.
# after server done, server sends result back to client's
# callback reply Q where client subscribed to.
#

amqp = require 'amqp'
fs = require 'fs'
util = require 'util'
assert = require 'assert'
net = require 'net'
util = require 'util'
url = require 'url'
http = require 'http'
https = require 'https'

cluster = require 'cluster'
cpus = require('os').cpus().length
EventEmitter = require('events').EventEmitter

# global settings to increase agent pool
require('http').globalAgent.maxSockets = 1000000

class Node extends EventEmitter
    constructor: (@client) ->

    @log: (msg, extra...) ->
        console.log msg, extra...

# ------------------------------------------------------------
# start amqp client, odd client pub msg and even client recv
# 0. obtain a connection to rabbitMQ server, an erlang server(ip:5672)
# 1. connection.exchange(), publishing to a non-existing exchange is forbidden.
# 2. connection.queue(name).bind(bindingKey) to create a queue.
# 3. after client creates and bind its queue, client uses this queue to
#    subscribeRaw() to ask exchge to put msg into this queue.
# 4. the msg will be lost if no queue is bound to the exchange yet.
# 5. exchange.publish(routingKey, msg, options, callback)
#     options: deliveryMode(non-persistent(1) or persistent(2)
#              priority, replyTo(name a reply queue for a request msg)
#
# Centeralized Arch: one server host one exchange
# All msgs are routed in/out to queues from/to eXchange.
# Each msg has a routingKey.
# Each Q has a bindingKey.
# eXchange route msg: msg's routingKey == Q's bindingKey.
#
# List of exchanges: sudo rabbitmqctl list_exchanges, list_bindings
#
# AMQP defines 14 props that go with a msg.
#   delivery mode, content type, reply to(name a callback Q),
#   correlation_id(id of slot in callback Q)
# ------------------------------------------------------------

#
# direct eXchange routing :
# eXchange routes msg to Q whose binding key matches msg's routing key.
# 1. server creates the rpc queue and listen to it.
# 2. client create reply callback queue, subscribe to it listening to callback
# 3. client publish to exchange, which goes to server rpc queue
# 4. server gets the msg from rpc queue, publish the result back to exchange.
# 5. client who subscribe to the reply callback queue gets the result back
#
# ------------------------------------------------------------

class AmqpRpcClient
    # class var, barrier is used to sync between workers
    @barrier = 0
    @serverId = 1   # worker 1 elected as server
    @clientId = 2   # worker 2 elected as client
    @clientCallbackQKey = 'clientcallbackqkey-'+AmqpRpcClient.clientId
    @serverQKey = 'serverqkey-'+AmqpRpcClient.serverId

    constructor: (@_Id, @name, options) ->
        @options = options || {}
        @options.defaultExchangeName = 'amqp.topic'
        @options.host = 'ec2-107-20-125-57.compute-1.amazonaws.com'
        @options.host = '107.20.125.57'
        @options.host = 'localhost'  # no need amqp prefix in amqp://localhost
        @options.port = 5672        # default amqp port 5672
        # one common eXchg for all, different queues for client and server.
        @exchangeName = 'rpc-exchange'
        # each worker need to have a unique queue name !
        @queueName = 'Queue-'+@_Id
        # queue's bindingkey for direct eXchg
        if @isClient()
            @qKey = AmqpRpcClient.clientCallbackQKey
        else if @isServer()
            @qKey = AmqpRpcClient.serverQKey
        else
            @qKey = 'qkey-'+@_Id

        # workers are separate processes, shared-nothing.
        # handle barrier event emitted when all subscribers are ready
        #this.on 'barrier', @barrierReady

        # create a conn to rabbitMq server upon creation
        @connection = amqp.createConnection @options
        @connection.on 'error', (e) ->
            Node.log 'connection to amqp service error:', e
            throw e
        @connection.on 'close', (e) ->
            Node.log 'connection closed.', e

        # once conn ready to the amqp server, create exchange and queue.
        @connection.on 'ready', @connectionReady

    # factory pattern
    @create : (id) ->
        return new AmqpRpcClient id, 'amqp-client'+id     # no options for now

    isClient : ->
        if @_Id == AmqpRpcClient.clientId
            return true
        return false

    isServer : ->
        if @_Id == AmqpRpcClient.serverId
            return true
        else
            return false

    # connection ready, create queue with Name and bind the queue with key.
    connectionReady : =>
        # one exchange for one unique name/type
        # the first call creates it and following calls get its ref.
        @exchange = @connection.exchange @exchangeName, {type: 'direct'}
        #Node.log 'creating exchange : ', @_Id, ' ', @exchangeName
        # Each Q is identified by its queue bindingkey, queue key.
        @queue = @connection.queue @queueName, =>
            # bind queue to exchange with bindingKey
            @queue.on 'queueBindOk', () =>
                Node.log @_Id, ' created and bind queue : ', @queueName, @qKey
                # each client creates its queue and subscribe to recving msg.
                @subscribeToQueueRaw(@queueName) # all client subscribe to its queue
                #if @_Id == 1   # different worker take different roles here
                #    @subscribeToQueueRaw()
                #else
                #    @publishToQueue()
            @queue.bind @exchange, @qKey


    # now client has the queue, then ask exchange to send subscribed msg to this queue
    subscribeToQueueRaw : (qname) =>

        #Node.log 'subscribe to queue...worker :', @_Id
        @queue.subscribeRaw (m) =>

            m.on 'data', (chunk) =>
                Node.log @_Id, qname, 'getting data :', @_Id, chunk.toString()

            m.on 'end', () =>
                Node.log @_Id, 'getting msg from Q :', qname, 
                         'msg Tag :', m.deliveryTag, \
                         'msg routingkey:', m.routingKey, \
                         'msg corrId:', m.correlationId, \
                         'msg replyTo:', m.replyTo

                # server publishes msg routingkey = client's Q's bindingkey
                # when pub rpc result back, fillout correlationId
                # so client can correlate which result to which call
                if @isServer()
                    rpcResult = 'server responds rpc call result :' + @_Id + \
                                ' : corrId : ' + m.correlationId
                    Node.log @_Id, 'server handle rpc : ', rpcResult
                    options = {}
                    options.correlationId = m.correlationId
                    replyRpcResult = =>
                        @publishToQueue m.replyTo, \
                                    rpcResult + ' for corrId:'+m.correlationId,\
                                    options
                    setTimeout replyRpcResult, 5000
                m.acknowledge()

        # callback when subscribe succeed, before msg comes into the queue.
        @queue.on 'basicConsumeOk', () =>
            #process.send {'subscriber' : 1}
            if @isClient()
                Node.log @_Id, ' basicConsumeOK : ', @_Id, ' start rpc'
                @startRpc()

            #if AmqpRpcClient.barrier == cpus - 1
            #    Node.log 'basicConsumeOk : emitting barrier event. ', @_Id
            #    emit 'barrier', AmqpRpcClient.barrier

    # worker 1 as RPC client start rpc to RPC server, worker 2.
    startRpc : =>
        if @isClient()
            options = {}
            options.correlationId = 'fake-hardcode-1234'
            options.replyTo = @qKey        # replyto queue routing key
            msg = 'client ' + @_Id + ' RPC : reply to :' + @queueName
            # pub msg to server's Q with server routing key
            Node.log @_Id, 'client ', @_Id, ' startRpc :', msg
            @publishToQueue AmqpRpcClient.serverQKey, msg, options

    # publish msg to queue key through exchange rout by queue key.
    publishToQueue : (qkey, msg, options) =>
        #msgbody = 'this is msgbody from worker :' + @_Id
        Node.log @_Id, 'publishToQueue : q routingkey ', qkey, 
                 'reply To : ', options.replyTo, ' >> ', msg
        # publish(routingkey, data, options, callback)
        @exchange.publish qkey, msg, options, () ->
            #Node.log 'exchange.publish succeed !'

    # when barrier ready, start the publishing
    barrierReady : (barriers) =>
        Node.log 'barrier ready...', barriers
        if @_Id is 1
            Node.log 'worker ', @_Id, ' start to publishing...'
            @publishToQueue()

    toString : () ->
        return 'AmqpRpcClient: ' + @name + ' ' + @options.host

exports.AmqpRpcClient = AmqpRpcClient

# ------------------------------------------------------------
# end of amqp client
# ------------------------------------------------------------

#
# main entry for test
# master forks 4 workers, and wait for workers ready.
# once worker created, it connects to exchge and creates its queues in exchge.
# then client sub to queue raw
#
main = ->
    if cluster.isMaster
        for i in [0..cpus-1]
            cluster.fork()  # dev

        barriers = 0
        # re-start the worker once it dies
        cluster.on 'death', (worker) ->
            Node.log 'worker dead...' + worker.pid
            cluster.fork()

        cluster.on 'listening', (worker, address) ->
            Node.log 'worker : ' + worker.id + ' listening on ' + \
                     address.address + ' : ' + address.port

        # master handles events emitted from each worker
        Object.keys(cluster.workers).forEach (id) ->
            # each worker endpoint will emit event to master
            cluster.workers[id].on 'message', (msg) ->
                barriers += 1
                Node.log 'master handler worker msg:', 'worker:', id, ' barriers:', barriers, msg
                if barriers == cpus-1    # all worker thread ready, release the barrier
                    cluster.workers[1].send 'start publishing'

    else
        # from here, running in a separate process.
        # each worker create a new client. odd client pub and even client sub
        amqpclient = AmqpRpcClient.create(cluster.worker.id)

        # each worker handles message from master.
        cluster.worker.on 'message', (msg) =>
            Node.log 'worker: ' + cluster.worker.id + ' on message: ' + \
                     JSON.stringify(msg)
            #amqpclient.publishToQueue()

#process.on 'uncaughtException', (err) ->
#    Node.log 'uncaughtException: ' + err

main()
