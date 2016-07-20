#!/usr/bin/env coffee

#
# utill to populate mysql blacklist
#

fs = require('fs')
path = require('path')
net = require('net')
util = require('util')
mysql = require('mysql')
EventEmitter = require('events').EventEmitter

#
# mysql connection class encapsulate mysql connection handling
# methods, include connection establish, and retry logic.
#

class MySqlConn extends EventEmitter

    constructor : (options) ->
        @options = options
        @connection = undefined
        @connected = false
        @retryInterval = 5000  # retry every 5 seconds, when server is running

        @createConnection()
        console.log 'MySqlConn constructor:', options

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
                console.log 'mysql connection established !'
                @connected = true
                @createDB()
            else
                console.log 'mysql connection failed !', err

        @connection.on 'error', @handleConnectionError.bind(this)

    # Error handling, do I need to retry ?
    handleConnectionError : (err) ->
        console.log 'Mysql Connection Error :', err
        @connected = false
        if err.code is 'PROTOCOL_CONNECTION_LOST' or
           err.code is 'ECONNREFUSED'
            cb = @createConnection.bind(this)
            setTimeout cb, 5000

    createDB : ->
        console.log 'createDB: ', @options.usedbsql
        @connection.query @options.usedbsql
        @.emit('connected', null)

    # select sql
    query : (sql, cb) ->
        if @connected
            @connection.query sql, (err, rows) ->
                cb err, rows
        else
            # if no connection to verify blacklist, no blacklist
            cb 'disconnected', null

    # insert into tbl, options={pushid: xx, clientid: yy}
    insert : (sql, options, cb) ->
        @connection.query sql, options, (err, result) ->
            if typeof cb is 'function'
                cb err, result


# populate black list
class Blacklist extends EventEmitter
    cred = {
        host     : 'localhost',
        user     : 'root',
        password : 'elephant'
    }

    constructor : (options) ->
        @conn = MySqlConn.create options
        @conn.on 'connected', (e) =>
            console.log 'connection db established'
            @emit 'start', null

    # factory pattern
    @create : ->
        options = {}
        options.cred = cred
        options.dbname = 'spdyclient'
        options.usedbsql = 'use spdyclient;'
        return new Blacklist options

    # select sql
    query : (sql, cb) ->
        if @conn.connected
            @conn.connection.query sql, (err, rows) ->
                cb err, rows
        else
            # if no connection to verify blacklist, no blacklist
            cb 'query : no db connection:', null

    # insert into tbl, options={pushid: xx, clientid: yy}
    insert : (sql, options, cb) ->
        @conn.connection.query sql, options, (err, result) ->
            console.log 'blacklist insert :', options, err
            if typeof cb is 'function'
                cb err, result

    # add a pushid to blacklist
    addRevokedId : (clientId, pushId, cb) ->
        if not clientId or not pushId
            return

        sql = ' REPLACE INTO blacklist SET ?'
        options = {}
        options.pushid = pushId
        options.clientid = clientId
        options.lastseen = Math.round(Date.now()/1000)
        @insert sql, options, cb

    useDb : ->
        @query 'use spdyclient;', (err, result) ->
            console.log 'done using db'

    # populate clients list
    populateDb: (filename) ->
        f = path.resolve filename
        clients = fs.readFileSync(f).toString().split('\n')
        for c in clients
            console.log 'revoked_Id : ', c
            clid = c.split(' ')[0]
            puid = c.split(' ')[1]
            @addRevokedId clid, puid, (err, result) ->
                console.log 'inserted: ', err, result

module.exports.MySqlConn = MySqlConn
module.exports.Blacklist = Blacklist

# unit
unit = ->
    blacklist = Blacklist.create()
    blacklist.on 'start', ->
        console.log 'starting...'
        blacklist.useDb()
        blacklist.populateDb('./blacklist.txt')

unit()
