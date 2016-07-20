#!/usr/bin/env coffee

Interface = require('./interface')
Models = require('../model/models')


FileStream = require('../common/filestream').FileStream
Config = require('../config/config')
Logging = require('../common/logging')
moment = require('moment')


#
# Persistent client information into mysql database
# we are using sequelize lib as our ORM layer to interface with mysql database.
# 

# Per programming to abstract, programming to interface rule, we use interface 
# object to decouple storage operations from app. The advantages for this:
#   1. the APIs for any pluggable module shall impl is explicitly called out.
#   2. we only expose the interface api object, hiding all the internal functions.
#   3. though we can not enforce interface at compile time, it is clear at reading.

#
# Connection failure and error handling is wrapped inside our sequelize wrapper.
#
# client indexed by pushId
# Supported operations:
#   add, get, remove, removeByClientId,
#


# client map storage with mysql
class MySqlClientMap

    logger = Logging.getLogger "mysql-client-map"

    constructor: ->
        # see module comments above for the reason of using interface object here.
        @storageIface = Interface()
        @storageIface['add'] = @add.bind(this)
        @storageIface['remove'] = @remove.bind(this)
        @storageIface['removeByClientId'] = @removeByClientId.bind(this)
        @storageIface['update'] = @update.bind(this)
        @storageIface['getNumClients'] = @getNumClients.bind(this)
        @storageIface['getClient'] = @getClient.bind(this)
        @storageIface['getAllClients'] = @getAllClients.bind(this)
        @storageIface['dumpClients'] = @dumpClients.bind(this)

        # demonstrate that we can never mistakenly remove database in production.
        if Config.getConfig 'UNIT_TEST'
            @storageIface['purge'] = @purge.bind(this)

        @createSchema()


    # define models for the
    createSchema: ->
        
        @clientModel = Models.clientMapModel

        onSuccess = ->
            logger.debug "database schema created success !"
            
        
        onError = (err) ->
            logger.error "database schema created error #(err.code}"
        

        # bind sync function's this ref. Retry will be handled inside wrapper.
        Models.SequelizeWrapper.executeWithRetry @clientModel.sync.bind(@clientModel), 
                                                 onSuccess, 
                                                 onError

        

    # factory pattern
    @create: ->
        clientModel = new MySqlClientMap
        # return interface object, not the model object. only expose interface APIs, 
        # hiding all other internal functions.
        return clientModel.storageIface

   
    # get the num of clients in the map
    getNumClients: (onDone)->
        @clientModel.count().success (count) ->
            if typeof onDone is 'function'
                onDone count


    # findAll clients
    getAllClients: (onDone) ->
        onSuccess = (clients) ->
            if typeof onDone is 'function'
                onDone null, clients

        onError = (err) ->
            logger.error "get all clients model error #{err.code}"
            if typeof onDone is 'function'
                onDone err, null

        @clientModel.findAll().success(onSuccess)
                              .error(onError)

    # get push client
    getClient: (pushId, onDone) ->
        # success handler
        onSuccess = (row) ->
            client = if row? then row else null
            logger.debug "get push client success #{client?.pushid}"
            
            if typeof onDone is 'function'
                onDone null, client

        # error handler
        onError = (err) ->
            logger.error "get push client err #{err.code}"
            if typeof onDone is 'function'
                onDone err, null

        query =
            where:
                pushid: pushId
            attributes: ['pushid', 'clientid', 'hostname', 'workerid', 'timestamp']

        logger.debug "get connected pushId #{pushId}"
        @clientModel.find(query).success(onSuccess)
                                .error(onError)
  
    ###
    # add a client as push client, find first, if found, update, insert otherwise
    # @param pushId is the primary key
    # @param clientId, serverId, workerId
    # @param onDone callback upon add complete
    ###
    add: (pushId, clientId, serverId, workerId, onDone) ->

        # on found client in database
        onFound = (err, client) =>
            if err?
                if typeof onDone is 'function'
                    onDone err, null
                    return
            
            logger.debug "add #{pushId} #{serverId} #{workerId} find? #{client}"

            if not client?
                @insert pushId, clientId, serverId, workerId, onDone
            else
                @updateInstance client, pushId, clientId, serverId, workerId, onDone

        @getClient pushId, onFound


    # insert a new client into client map
    insert: (pushId, clientId, serverId, workerId, onDone) ->
        instance = @clientModel.build({
            'pushid': pushId
            'clientid': clientId
            'hostname': serverId
            'workerid': workerId
            'timestamp': moment().unix()
        })
        

        onSuccess = (row) ->
            logger.debug "insert push client #{row?.pushid} #{row?.clientid} #{row?.hostname}"
            if typeof onDone is 'function'
                onDone null, row

        onError = (err) ->
            logger.error "insert push client error #{pushId} #{clientId} #{err.code}"
            if typeof onDone is 'function'
                onDone err, null

        instance.save().success(onSuccess)
                       .error(onError)

    ###
    # update a client instance
    # @param client the client instance we got from find query
    # @param pushId, clientId, serverId, workerId
    # @onDone callback upon update complete
    ###
    updateInstance: (client, pushId, clientId, serverId, workerId, onDone) ->
        attribute =
            'clientid': clientId
            'hostname': serverId
            'workerid': workerId
            'timestamp': moment().unix()
        
        attributeKeys = Object.keys attribute

        onSuccess = (row) ->
            logger.debug "update client #{row?.pushid} #{row?.clientid} #{row?.hostname}"
            if typeof onDone is 'function'
                onDone null, row

        onError = (err) ->
            logger.error "update client error #{pushId} #{clientId} #{err}"
            if typeof onDone is 'function'
                onDone err, null

        logger.debug "update client #{pushId} #{serverId} #{client.hostname}"
        client.updateAttributes(attribute, attributeKeys).success(onSuccess)
                                                         .error(onError)

    ###
    # update client map with value object that has all attributes, called from
    # app server process update client with clientId and pushId.
    # @param pushId is the pri key of connected_push_id table.
    # @param value map contains client model attributes; Column name is case insenstive.
    ###
    update: (pushId, valueMap, onDone) ->

        onSuccess = ->
            logger.debug "update client model success #{pushId}"
            onDone? null, 

        onError = (err) ->
            logger.error "update client model error #{err.code}"
            onDone? err, null

        # where clause with key pushid, the pri key of the table.
        where =
            pushid: pushId

        @clientModel.update(valueMap, where).success(onSuccess)
                                            .error(onError)


    # internal function to remove client by either pushId or clientId
    # either of the push id or client id shall be valid, but not both.
    removeById: (pushId, clientId, onDone) ->

        onDeleteSuccess = ->
            logger.debug "remove push client #{pushId} #{clientId}"
            if typeof onDone is 'function'
                onDone null, pushId

        onDeleteError = (err) ->
            logger.error "remove push client err #{pushId} #{clientId} #{err.code}"
            if typeof onDone is 'function'
                onDone err, pushId

        deleteQuery = {}
        if pushId?
            deleteQuery.pushid = pushId
        else if clientId?
            deleteQuery.clientid = clientId

        logger.info "removing push client", { pushId: pushId, removeByClientId: clientId? }
        @clientModel.destroy(deleteQuery).success(onDeleteSuccess)
                                         .error(onDeleteError)


    # remove a push client after done
    remove: (pushId, onDone) ->
        @removeById pushId, undefined, onDone
        

    # re-use the remove code to avoid boilerplate code
    removeByClientId : (clientId, onDone) ->
        @removeById undefined, clientId, onDone

    # remove all push clients
    purge: (done) ->

        logger.debug "purging client map"

        @clientModel.destroy().complete(done)


    # dump all clients info into the file. For test verification.
    dumpClients : (filename) ->
        
        onSuccess = (clients) ->
            FileStream.dumpArray filename, clients

        onError = (err) ->
            logger.error "dump client model error #{err.code}"


        @clientModel.findAll().success(onSuccess)
                              .error(onError)
        

module.exports = MySqlClientMap

