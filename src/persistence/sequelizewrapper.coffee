#!/usr/bin/env coffee

#
# this module is a wrapper of sequelize lib that we used as our ORM model layer.
# It establishes connection to mysql database and application should use this
# wrapper instead of handling database connection directly.
#

net = require('net')
util = require('util')

Config = require('../config/config')
Logging = require('../common/logging')
retry = require('retry')

#
# sequelize wrapper interfaces to underlying sequelize ORM layer.
# It handles database connection, and retry any database function upon database
# connection failure.
#
class SequelizeWrapper

    # class static logger
    logger = Logging.getLogger "sequelize"


    # db operation retry options upon db connection error.
    retryOptions =
        retries: 60       # idealy, on db error, we should spin or panic.
        minTimeout: 500   #  reconnect every half second.
        maxTimeout: 500   # 


    constructor: ->
        dbOptions = Config.getConfig 'DB'
        storage = dbOptions.storage
        @connection = new storage dbOptions.database, 
                                  dbOptions.user, 
                                  dbOptions.password, 
                                  dbOptions.options
        logger.info "creating database #{dbOptions.table} #{dbOptions.options.dialect}"


    # factory pattern
    @create: ->
        sequelize = new SequelizeWrapper
        return sequelize.connection


    # attempt a database operation and handle retries gracefully
    @executeWithRetry: (fn, onSuccess, onError) ->
        # first, create retry operation with backoff options
        attemptOperation = retry.operation SequelizeWrapper.retryOptions

        # error code ['ECONNREFUSED', 'ER_ACCESS_DENIED_ERROR', 'ENOTFOUND', 'EHOSTUNREACH']
        onAttemptError = (err) ->
            # ret false when no err, or max retry reached, 
            # Otherwise, ret true and retry the operation after backoff.
            if attemptOperation.retry err
                logger.error "db operation error keep retrying #{err.code}"
            else 
                logger.error "db operation error retry done: #{attemptOperation.attempts()}"
                onError err

        # invoke the passed in function with retry attempt.
        attemptFunction = ->
            fn().success(onSuccess)
                .error(onAttemptError)

        attemptOperation.attempt attemptFunction

        
module.exports = SequelizeWrapper
