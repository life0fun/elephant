#!/usr/bin/env coffee

#
# Persistent client information into local object hash.
# client map indexed by pushId
# Supported operations:
#   add, get, remove, removeByClientId,
#

Config = require('../config/config')
Interface = require('./interface')
FileStream = require('../common/filestream').FileStream
ElephantError = require('../common/error')
Logging = require('../common/logging')
PoolLayer = require('../pool/poollayer')


#
# Client Map holds the global information about all clients.
#
# For the performance of object map, please refer to test/maptest.coffee
# We can have object up to 2M keys efficiently.
# However, we need to have num keys counter.
#
class ObjectMap

    logger = Logging.getLogger "object-map"

    constructor : (options) ->
        @options = options || {}

        @numClients = 0
        @clientmap = {}    # object map with 1m keys

        @storageIface = Interface()
        @storageIface['add'] = @add.bind(this)
        @storageIface['remove'] = @remove.bind(this)
        @storageIface['removeByClientId'] = @removeByClientId.bind(this)
        @storageIface['purge'] = @purge.bind(this)
        @storageIface['getNumClients'] = @getNumClients.bind(this)
        @storageIface['getClient'] = @getClient.bind(this)
        @storageIface['getAllClients'] = @getAllClients.bind(this)
        @storageIface['dumpClients'] = @dumpClients.bind(this)

        @addTestData()

    addTestData: () ->
        localAddress = PoolLayer.getServerAddress()
        # add fake client id and push id for unit test, clid-1/2 was revoked.
        @storageIface['add']("puid-11", "clid-11", localAddress, 0, null)
        @storageIface['add']("puid-12", "clid-12", localAddress, 0, null)
        @storageIface['add']("puid-13", "clid-13", localAddress, 0, null)
        @storageIface['add']("puid-14", "clid-14", localAddress, 0, null)
        @storageIface['add']("puid-15", "clid-15", localAddress, 0, null)
        @storageIface['add']("puid-16", "clid-16", localAddress, 0, null)
        @storageIface['add']("puid-17", "clid-17", localAddress, 0, null)
        @storageIface['add']("puid-18", "clid-18", localAddress, 0, null)

        @storageIface['add']("puid-21", "clid-21", localAddress, 0, null)
        @storageIface['add']("puid-22", "clid-22", localAddress, 0, null)
        @storageIface['add']("puid-23", "clid-23", localAddress, 0, null)
        @storageIface['add']("puid-24", "clid-24", localAddress, 0, null)
        @storageIface['add']("puid-25", "clid-25", localAddress, 0, null)

        # simulate clients connected on a peer elephant server
        @storageIface['add']("puid-30", "clid-30", "127.0.0.1:8444", 0, null)
        @storageIface['add']("puid-31", "clid-31", "127.0.0.1:8445", 0, null)
    
    # factory pattern
    @create : (options) ->
        objmap = new ObjectMap options
        return objmap.storageIface

    # get id not exist err object
    idNotExistError : (id, func) ->
        err = ElephantError.create ElephantError.PUSH_ID_NOT_EXIST, \
                                   'objectclientmap id not exist:'+ id, \
                                   'objectclientmap', func
        return err

    # get the num of clients in the map
    getNumClients : (cb) ->
        if typeof cb is 'function'
            cb @numClients

    # get client push Id as a list
    getAllClients : (cb) ->
        if typeof cb is 'function'
            cb Object.keys(@clientmap)

    # private for getClient, return err obj if non exist
    hasClient : (pushId) ->
        err = null
        if not @clientmap.hasOwnProperty(pushId)
            logger.warn "hasClient #{pushId} #{@clientmap[pushId]}"
            err = @idNotExistError pushId, 'hasClient'
        return err

    # get client by pushId, when client does not exist, pass id not exist error
    # to callback.
    getClient : (pushId, cb) ->
        err = @hasClient pushId

        # non-exist id is not an error, non exist attr is undefined.
        if typeof cb is 'function'
            cb null, @clientmap[pushId]

    # add client into map, if client id exists, overwrite
    add : (pushId, clientId, serverId, workerId, cb) ->
        # increase num clients when newly added id
        idNotExistErr = @hasClient pushId
        if idNotExistErr
            @numClients += 1

        # set valid client when first create
        clientModel =
            pushid: pushId
            clientid: clientId
            hostname: serverId
            workerid: workerId
            timestamp: Date.now()

        @clientmap[pushId] = clientModel

        logger.debug "adding #{pushId} tot #{@numClients}"

        if typeof cb is 'function'
            cb null, clientModel

    update : (clientId, valueObj, cb) ->
        client = @findByClientId clientId
        if client
            client.pushId = valueObj.pushId

        if typeof cb is 'function'
            cb null, client

    # delete client by pushId
    remove : (pushId, cb) ->
        err = @hasClient pushId
        if not err
            delete @clientmap[pushId]
            @numClients -= 1
        else
            logger.error 'ObjectMap remove: wrong pushId :', pushId
        logger.debug 'objectMap remove :', pushId, ' tot: ', @numClients

        if typeof cb is 'function'
            cb err, pushId

    #
    # delete a client by clientId
    removeByClientId : (clientId, cb) ->
        client = @findByClientId clientId
        if client
            @remove client.pushId, cb
        else
            err = @idNotExistError clientId, 'removeByClientId'
            logger.error 'ObjectMap removeByClientId : wrong :', clientId
            if typeof cb is 'function'
                cb err, clientId

    # delete all clients, except the test clients.
    purge: (cb) ->
        @clientmap = {}
        @numClients = 0
        @addTestData()

        cb? null

    # iterate the map to find client with clientkey
    findByClientId : (clientId) ->
        for e of @clientmap
            if @clientmap[e].clientId is clientId
                logger.debug 'find client by clientId :', clientId, pushId
                return @clientmap[e]
        return null


    # dump clients
    dumpClients : (filename) ->
        FileStream.dumpCollection filename, @clientmap


module.exports = ObjectMap

