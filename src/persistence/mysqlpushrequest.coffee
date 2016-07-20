#!/usr/bin/env coffee

#
# this module interface with underlying ORM lib for pending push
# request meta persistence.
# we are using sequelize library for ORM management.
#

net = require('net')
util = require('util')
moment = require('moment')

Config = require('../config/config')
Logging = require('../common/logging')
Helper = require('../common/helper')

Models = require('../model/models')

#
# push request mysql storage is plug-in layer for storing push request
# into mysql database.
# Note that for ORM CRUD unit test, we use sqlite in memory database.
#
class PushRequestMysqlStorage

    # class static logger
    logger = Logging.getLogger "pushreq-mysql"
    
    
    # db connection success callback
    onSuccess = ->
        logger.info "push request storage db connected successfully !"

    # db connection error callback, an error will be thrown.
    onError = (err) ->
        logger.error "push request storage db connected failed #{err}"
        throw ElephantError.create ElephantError.MYSQL_ERROR,
                                   "database schema created error",
                                   "mysqlpushrequest.coffee",
                                   "createSchema"
        
    # create database schema, put it on top of scope chain.
    # idempotency, wont have side effect when schema exists.
    createSchema: ->
        @pushRequestModel = Models.pushRequestModel
        syncFn = @pushRequestModel.sync.bind(@pushRequestModel)
        Models.SequelizeWrapper.executeWithRetry syncFn, onSuccess, onError

    constructor: (appOptions) ->
        @createSchema()
    

    # factory pattern
    @create: (options) ->
        return new PushRequestMysqlStorage options


    # get push request by db id, here the id is index in mem
    getPushRequestByIndex: (pushIndex, done) ->

        @pushRequestModel.find(pushIndex).complete(done)

    
    # add push request to the storage
    addPushRequest: (pushRequest, done) ->

        logger.debug "adding push request", {
            pushId: pushRequest.pushId
            requestId: pushRequest.requestId
        }

        instance = @pushRequestModel.build {
            requestId: pushRequest.requestId
            clientId: pushRequest.clientId
            pushId: pushRequest.pushId
            serverId: pushRequest.serverId
            workerId: pushRequest.workerId
            startTime: pushRequest.startTime
    
            callbackUrl: pushRequest.callbackUrl
            callbackUsername: pushRequest.callbackUsername
            callbackPassword: Helper.aesEncrypt pushRequest.callbackPassword
        }

        instance.save().complete(done)

    # delete push request by index
    deletePushRequestByIndex: (pushIndex, done) ->

        logger.debug "deleting push request", {
            pushIndex: pushIndex
        }
    
        @pushRequestModel.destroy({ id: pushIndex }).complete(done)

    # purge all push requests.
    purge: (done) ->

        # never allow to purge database in production.
        if not Config.getConfig('UNIT_TEST') then return

        logger.debug "purging push requests"
         
        @pushRequestModel.destroy().complete(done)
    

module.exports = PushRequestMysqlStorage
