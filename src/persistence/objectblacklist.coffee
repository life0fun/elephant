#!/usr/bin/env coffee

#
# store a list of revoked client ids and push ids
# use object hash to store info.
# mainly for test only!
#
class BlacklistObjectStorage

    constructor : (@options) ->
        @revoked_client_id = {}
        @revoked_push_id = {}
        @refresh_count = {}

    # factory pattern
    @create : ->
        options = {}
        storage = new BlacklistObjectStorage options
        return storage

    # get refresh count for a clientid
    getRefreshCount: (clientId, cb) ->
        cnt = 0
        if @refresh_count.hasOwnProperty clientId
            cnt = @refresh_count[clientId]
        cb null, clientId, cnt

    # get revoked clientId
    getRevokedClientId: (clientId, cb) ->
        rvkedCliObj = @revoked_client_id[clientId]
        cb null, rvkedCliObj   # return null if no revoked client

    # get revoked pushId, pushId gened by salting hash clientId
    getRevokedPushId: (pushId, cb) ->
        rvkedCliObj = @revoked_push_id[pushId]
        cb null, rvkedCliObj

    # revoke a clientId into revoked client table
    revokeClientId: (clientId, reason, cb) ->
        options = {}
        options.clientid = clientId
        options.timestamp = Math.round(Date.now()/1000)
        options.memo = reason
        @revoked_client_id[clientId] = options
        cb null, options

    # revoke a pushId into revoked push table
    revokePushId: (pushId, clientId, reason, cb) ->
        options = {}
        options.pushid = pushId
        options.clientid = clientId
        options.memo = reason
        options.timestamp = Math.round(Date.now()/1000)
        @revoked_push_id[pushId] = options
        cb null, options

    # increment refresh count for certain client id
    incrementRefreshCount: (clientId, cb) ->
        entry = @refresh_count[clientId]

        if not entry
            entry =
                clientid: clientId
                count: 1
        else
            entry.count += 1
    
        @refresh_count[clientId] = entry
        cb()


module.exports = BlacklistObjectStorage
