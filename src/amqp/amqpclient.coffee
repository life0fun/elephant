#!/usr/bin/env coffee

#
# node amqp client that interacts with rabbitMQ to
# pub/recv msg in distributed environments.
#

#nodetime = require('nodetime').profile()
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
# 0. establish connection.
# 1. declare exchange, publishing to a non-existing exchange is forbidden.
# 2. create a queue.
# 3. bind queue to the exchange with routingKey to the queue
# 4. queue.subscribeRaw() to get the msg from the queue <- exchange
# 5. the msg will be lost if no queue is bound to the exchange yet.
#    you can use delivery_mode = 'persistent'
#
# List of exchanges: sudo rabbitmqctl list_exchanges, list_bindings
#
# AMQP defines 14 props that go with a msg.
#   delivery mode, content type, reply to(name a callback Q),
#   correlation_id(id of slot in callback Q)
#
# ------------------------------------------------------------

class AmqpClient extends Node
    # class var, barrier is used to sync between workers
    @barrier = 0

    constructor: (@_Id, @name, options) ->
        @options = options || {}
        @options.defaultExchangeName = 'amqp.topic'
        # no need amqp prefix in amqp://localhost
        @options.host = 'localhost'
        @options.port = 5672        # default amqp port 5672
        @exchangeName = 'push-exchange'
        # each worker need to have a unique queue name !
        @queueName = 'push-queue'+@_Id
        @routingKey = '*'

        # workers are separate processes, shared-nothing.
        # Class variable works only with many instances in one JVM.
        # handle barrier event emitted when all subscribers are ready
        #this.on 'barrier', @barrierReady

        # create a conn to rabbitMq server
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
        return new AmqpClient id, 'amqp-client'+id     # no options for now

    # handle connection ready, either ready to pub or sub
    connectionReady : () =>
        # only one exchange, whoever creates it exists.
        # if exchange name is the same for all workers,
        @exchange = @connection.exchange @exchangeName, {type: 'fanout'}
        #Node.log 'creating exchange : ', @_Id, ' ', @exchangeName
        @queue = @connection.queue @queueName, () =>
            #Node.log 'creating queue : ', @_Id, ' ', @queueName
            # bind queue to exchange with routingKey
            @queue.bind @exchange, @routingKey
            @queue.on 'queueBindOk', () =>
                #Node.log 'queue bind ok : ', @_Id, ' ', @queueName
                # different worker take different roles here. even worker sub
                if @_Id != 1
                    @subscribeToQueueRaw()
                else
                    @publishToExchange()


    # subscribe from Queue to get msg.
    subscribeToQueueRaw : () =>
        Node.log 'subscribe to queue...', @_Id

        @queue.subscribeRaw (m) =>
            Node.log @_Id, 'get msg : Tag :', m.deliveryTag, \
                            ' routingkey:', m.routingKey
            m.on 'data', (chunk) =>
                Node.log @_Id, ' <<  ', chunk.toString()
            m.on 'end', () =>
                Node.log 'ending msg...', JSON.stringify(m.headers)
                m.acknowledge()

        # callback when subscribe succeed, before msg comes into the queue.
        @queue.on 'basicConsumeOk', () =>
            # raw msg includes
            AmqpClient.barrier += 1
            Node.log 'basicConsumeOK : ', @_Id, \
                     'successfully subscribe to queue:', AmqpClient.barrier
            process.send {'subscriber' : 1}
            if AmqpClient.barrier == cpus - 1
                Node.log 'basicConsumeOk : emitting barrier event. ', @_Id
                emit 'barrier', AmqpClient.barrier

    # publish msg to eXchange
    publishToExchange : () =>
        msgbody = 'this is msgbody from worker :' + @_Id
        Node.log @_Id, ' >> ', ' exchange publish : ',  @_Id, ' ', msgbody
        @exchange.publish 'msg title from '+ @_Id, \
                          'round: 1 ' + msgbody, {contentType : 'text/plain'}


    # when barrier ready, start the publishing
    barrierReady : (barriers) =>
        Node.log 'barrier ready...', barriers
        if @_Id is 1
            Node.log ' worker ', @_Id, ' start to publishing...'
            @publishToExchange()


    toString : () ->
        return 'AmqpClient: ' + @name + ' ' + @options.host

exports.AmqpClient = AmqpClient

# ------------------------------------------------------------
# end of amqp client
# ------------------------------------------------------------

#
# main
#
main = () ->
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
                Node.log 'master handler worker msg:', id, msg
                barriers += 1
                if barriers == cpus-1
                    cluster.workers[1].send 'start publishing'

    else
        # from here, running in a separate process.
        # each worker create a new client. odd client pub and even client sub
        amqpclient = AmqpClient.create(cluster.worker.id)
        Node.log 'starting worker: ' + cluster.worker.id

        # function(){}.bind(this) bind (this) to function. no flexibility
        # setInterval SPDYServer.periodicalPush.bind(server), 5000

        # each worker handles message from master.
        cluster.worker.on 'message', (msg) =>
            Node.log 'worker: ' + cluster.worker.id + ' on message: ' + \
                      JSON.stringify(msg)
            #amqpclient.publishToExchange()

#process.on 'uncaughtException', (err) ->
#    Node.log 'uncaughtException: ' + err

main()
