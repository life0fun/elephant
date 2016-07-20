#!/usr/bin/env coffee

#
# Abstract global look up table to find which server the client is connected.
# mapping client to server and the worker inside the server.
#
# support the following operations:
#   1. add(clientId, pushId, serverId, workerId)
#   2. get(pushId)
#   3. removeByPushId
#   4. removeByClientId
#   5. removeByServerId
#
# delegate all the operations to underlying storage layer.
#
# The persistent layer can use local object as hashmap, or mysql, or redis, or mongoDB.
# This should be configurable by node env
#

#
# connected_push_id table
#
# +---------+----------+----------------+----------+------------+
# | pushid  | clientid | hostname       | workerid | timestamp  |
# +---------+----------+----------------+----------+------------+
# | MjwCHQ= | rlient-1 | localhost:9443 | 2        | 1360103687 |
# +---------+----------+----------------+----------+------------+
#
# there are two paths to clean up records in client map:
#  1. when worker dies, new worker spawned, and workerid changes 
#     when app push, after validation all done, trying to send request to
#     worker, cluster.workers[workerId] will be wrong. clean up record
#     inside newPushRequest sendMsgToWorker 
#
#  2. when worker is not down, but has some stale records from dead clients.
#     worker getSession null, return 404.
#     app server will clean it up upon 404 push result
#

net = require('net')
util = require('util')


Storage = require('../persistence/index')()

#
# client object encapsulates properties about which server client is associated to.
# Information is persisted in memory object or in mysql db.
# After information retrieved from persistent layer, convert it to client object.
#
# each client has the following properties:
#   pushId, clientId, serverId, workerId, and timestamp.
#   serverId is mapped to hostname in database.
#
class Client

    constructor: (@pushId, @clientId, @serverId, @workerId, @timestamp) ->

    @create: (pushId, clientId, serverId, workerId, ts) ->
        return new Client(pushId, clientId, serverId, workerId, ts)

    toString : ->
        return @pushId + ' : ' + @clientId + ' : ' + \
               @serverId + ' : ' + @workerId + ':' + @timestamp

module.exports.Client = Client

#
# client info look up
# delegate all operations to underlying storage layer.
# some boilerplate code.
#
class ClientMap
    constructor: (options) ->
        # load client info from supported persistent method
        @allStorages = Storage.load()

        @options = options || {}
        if not @options.storage
            @options.storage = 'objectclientmap' # default in memory object map

        # create interface object
        @storage = Storage.create @options.storage

    # factory pattern
    @create: (options) ->
        return new ClientMap options

    # get the num of clients in the map
    getNumClients: ->
        return @storage.getNumClients()

    # get client by pushId
    getClient: (pushId, cb) ->
        @storage.getClient pushId, (err, clientModel) ->
            if err then return cb err
            if clientModel
                client = Client.create clientModel.pushid,
                                       clientModel.clientid,
                                       clientModel.hostname,
                                       clientModel.workerid,
                                       clientModel.timestamp
            cb null, client

    # get all clients
    getAllClients: (cb)->
        @storage.getAllClients cb

    # add client, too long args.
    add: (pushId, clientId, serverId, workerId, cb) ->
        @storage.add(pushId, clientId, serverId, workerId, cb)

    # delete client from clientMap
    remove: (pushId, cb) ->
        @storage.remove pushId, cb

    # remove by clientId
    removeByClientId: (clientId, cb) ->
        @storage.removeByClientId(clientId, cb)

    # remove all clients.
    purge: (cb) ->
        @storage.purge cb

    # update client map by clientId
    update: (clientId, valueObj, cb) ->
        @storage.update clientId, valueObj, cb

    # no callback
    dumpClients: (filename)->
        @storage.dumpClients filename

exports.ClientMap = ClientMap

# unit test

