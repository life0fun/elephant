#!/usr/bin/env coffee

#
# store a list of revoked client ids and push ids
# Those info got Persistent into mysql
#

net = require('net')
util = require('util')
moment = require('moment')

Config = require('../config/config')
Logging = require('../common/logging')

Models = require('../model/models')

#
# storage layer for blacklist
# db connection should be composition of storage
# storage should not inheritant db connection. Liskov
#
class BlacklistMysqlStorage

    # class static logger
    logger = Logging.getLogger "blacklist-mysql"
    
    # define models
    defineModels: ->
        # load all models
        @revokedClientIdModel = Models.revokedClientId
        
        @revokedPushIdModel = Models.revokedPushId
        
        @refreshCountModel = Models.refreshCount

        
        onSuccess = ->
            logger.info "database schema created success !"
            
        
        onError = (err) ->
            logger.error "database schema created error #(err.stack}"
            throw ElephantError.create ElephantError.MYSQL_ERROR,
                                       "database schema created error",
                                       "mysqlblacklist.coffee",
                                       "defineModels"


        # bind sync function's this ref. Retry will be handled inside wrapper.
        revokedClientSyncFn = @revokedClientIdModel.sync.bind(@revokedClientIdModel)
        Models.SequelizeWrapper.executeWithRetry revokedClientSyncFn,
                                                 onSuccess, onError
        
        revokedPushSyncFn = @revokedPushIdModel.sync.bind(@revokedPushIdModel)
        Models.SequelizeWrapper.executeWithRetry revokedPushSyncFn,
                                          onSuccess, onError

        refreshCount = @refreshCountModel.sync.bind(@refreshCountModel)
        Models.SequelizeWrapper.executeWithRetry refreshCount,
                                          onSuccess, onError


    constructor: ->
        @defineModels()

    # factory pattern
    @create: ->
        return new BlacklistMysqlStorage


    getRefreshCount: (clientId, onResult) ->

        onSuccess = (row) ->
            onResult null, row?.count or 0

        onError = (err) ->
            onResult err

        query =
            where:
                clientid: clientId
            attributes: ['count']

        @refreshCountModel.find(query).success(onSuccess).error(onError)


    getRevokedClientId: (clientId, onResult) ->

        query =
            where:
                clientid: clientId
            attributes: ['clientid', 'memo', 'timestamp']

        @revokedClientIdModel.find(query).done(onResult)


    getRevokedPushId: (pushId, onResult) ->

        query =
            where:
                pushid: pushId
            attributes: ['pushid', 'clientid', 'memo', 'timestamp']

        @revokedPushIdModel.find(query).done(onResult)


    # revoke a clientId
    revokeClientId: (clientId, reason, onResult) ->
        instance = @revokedClientIdModel.build {
            'clientid': clientId
            'timestamp': moment().unix()
            'memo': reason
        }
        
        onSuccess = (row) ->
            logger.info "clientId revoked", { clientId: clientId, reason: reason }
            if typeof onResult is 'function'
                onResult null, row

        onError = (err) ->
            logger.error "revoke clientId error: #{err}", { clientId: clientId }
            if typeof onResult is 'function'
                onResult err

        instance.save().success(onSuccess).error(onError)
        

    # revoke a pushId
    revokePushId: (pushId, clientId, reason, onResult) ->
        onSuccess = (row) ->
            logger.info "pushId revoked", {
                pushId: pushId
                clientId: clientId
                reason: reason
            }
            if typeof onResult is 'function'
                onResult null, row

        onError = (err) ->
            logger.error "revoke pushId error: #{err}", {
                pushId: pushId
                clientId: clientId
            }
            if typeof onResult is 'function'
                onResult err

        
        instance = @revokedPushIdModel.build {
            'pushid': pushId
            'clientid': clientId
            'memo': reason
            'timestamp': moment().unix()
        }
        
        instance.save().success(onSuccess).error(onError)


    # increment refresh count for a client id
    incrementRefreshCount: (clientId, onResult) ->

        onError = (err) ->
            logger.error "increment refresh count error: #{err}", { clientId: clientId }
            if typeof onResult is 'function'
                onResult err

        onSuccess = (client) ->
            logger.info "incremented refresh count", { clientId: clientId }
            if typeof onResult is 'function'
                onResult null, client
            
        onFindOrCreate = (client, created) ->
            if created then return onSuccess(client)

            client.increment('count', { by: 1 }).success(onSuccess).error(onError)

        query =
            clientid: clientId

        @refreshCountModel.findOrCreate(query).success(onFindOrCreate).error(onError)


    # delete all revoked client id data, for unit test purpose
    deleteAllRevokedClientId: (onDone) ->
        @revokedClientIdModel.destroy({}).done(onDone)


    # delete all revoked push id data, for unit test purpose
    deleteAllRevokedPushId: (onDone) ->
        @revokedPushIdModel.destroy({}).done(onDone)

    
    # delete all refresh count data, for unit test purpose
    deleteAllRefreshCount: (onDone) ->
        @refreshCountModel.destroy({}).done(onDone)


module.exports = BlacklistMysqlStorage
