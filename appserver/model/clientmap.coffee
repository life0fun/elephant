#!/usr/bin/env coffee

#
# This serves as the global look up table for
# mapping client to server and the worker inside the server.
#

net = require('net')
util = require('util')

Node = require('../common/root')

#
# each client has the following properties
#
class Client extends Node
    constructor : (@clientId, @pushId, \
                  @serverId, @workerId, @lastTime) ->

    @create : (clientId, pushId, serverId, workerId) ->
        curtime = new Date().getTime()
        return new Client clientId, pushId, \
                          serverId, workerId, curtime

    setClientMapId : (mapid) ->
        @clientMapId = mapid

    toString : ->
        return @clientId + ' : ' + @pushId + ' : ' + 
               @serverId + ' : ' + @workerId + ' : ' + @clientMapId

#
# Client Map holds the global information about all clients.
# Master bookkeeps this data structure.
#
# For the performance of object map, please refer to test/maptest.coffee
# We can have object up to 2M keys efficiently. 
# However, we need to have num keys counter.
#
class ClientMap extends Node
    constructor : (options) ->
        @options = options || {}

        # 1 million clients list, inited to undefined.
        @max_clients = 1000 * 1000    # 1 million
        @numClients = 0
        @clientmap = {}    # object map with 1m keys
        @servermap = {}   # contains serverid and worke id

    # factory pattern
    @create : (options) ->
        return new ClientMap options

    dump : ->
        for c of @clientmap
            Node.log 'dump client: ', @clientmap[c].toString()

    getAllClients : ->
        l = []
        for c of @clientmap
            l.push @clientmap[c]
        return l

    hasClient : (clientId) ->
        if @clientmap.hasOwnProperty(clientId)
            return true
        return false

    # find client by clientId
    getClient : (clientId) ->
        return @clientmap[clientId]

    # delete client from clientMap
    deleteClientFromMap : (clientId) ->
        exist = delete @clientmap[clientId]
        @numClients -= 1 if exist
        Node.log 'clientMap delete :', clientId, ' tot: ', @numClients

    # insert client into map
    # be cautious to delete any existing client with the same id
    insertClientIntoMap : (clientId, pushId, serverId, workerId) ->
        @numClients += 1 if not @hasClient(clientId)

        cli = Client.create clientId, pushId, serverId, workerId

        @clientmap[clientId] = cli

        return cli

exports.Client = Client
exports.ClientMap = ClientMap

# unit test
#option = {host:'localhost', port:3000}
#cli_session = Session.createSession(option)

