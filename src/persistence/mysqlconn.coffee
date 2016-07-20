#!/usr/bin/env coffee

#
# store a list of revoked client ids and push ids
# Those info got Persistent into mysql
#

net = require('net')
util = require('util')
mysql = require('mysql')

Logging = require('../common/logging')

#
# mysql connection class encapsulate mysql connection handling
# methods, include connection establish, and retry logic.
#

class MySqlConn
    logger = Logging.getLogger "mysql-conn"

    constructor : (options) ->
        @options = options
        @connection = undefined
        @connected = false
        @retryInterval = 5000  # retry every 5 seconds, when server is running

        @createConnection()
        logger.debug 'MySqlConn constructor:', options

    # factory pattern
    @create : (options) ->
        conn = new MySqlConn options
        return conn

    # connect to mysql server
    # if connection failed, all connection.query() is NO-OP
    # no error returned, and you do not need to handle error.
    createConnection : ->
        if @connection
            @connection.end()
        @connection = mysql.createConnection(@options.cred)
        @connection.connect (err) =>
            if not err
                logger.info 'mysql connection established !'
                @connected = true
                @createDB()
            else
                logger.error 'mysql connection failed !', err
                @handleConnectionError err

        @connection.on 'error', @handleConnectionError.bind(this)

    # Error handling, do I need to retry ?
    handleConnectionError : (err) ->
        logger.error 'Mysql Connection Error :', err

        @connected = false
        if err.code is 'PROTOCOL_CONNECTION_LOST' or
           err.code is 'ECONNREFUSED'
            retryConnect = @createConnection.bind(this)
            setTimeout retryConnect, 5000
        # if server is done and restart, we should also retrying

    createDB : ->
        @connection.query @options.createdbsql
        @connection.query @options.usedbsql

        for sql in @options.createtblsql
            logger.info 'create table sql:', sql
            @connection.query sql


    # select sql
    query : (sql, onQueryComplete) ->
        if @connected
            @connection.query sql, (err, rows) ->
                onQueryComplete err, rows
        else
            # if no connection to verify blacklist, no blacklist
            onQueryComplete 'disconnected', null

    # insert into tbl, options={pushid: xx, clientid: yy}
    insert : (sql, options, onInsertComplete) ->
        @connection.query sql, options, (err, result) ->
            if typeof onInsertComplete is 'function'
                onInsertComplete err, result

module.exports.MySqlConn = MySqlConn
