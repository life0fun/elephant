#
# store a list of revoked client ids and push ids
# Those info got Persistent into mysql
#

#
# blacklist for revoked client id and push id
# storage layer can be local object hash, or mysql connection.
# depends on global storage options.
#
class Blacklist
    constructor: (@options) ->
        # currently we support mysql storage and object hash storage
        if @options.storage is 'mysqlclientmap'
            filename = 'mysqlblacklist'
        else if @options.storage is 'objectclientmap'
            filename = 'objectblacklist'
        else
            filename = 'mysqlblacklist'    # default use mysql

        #@storage = BlacklistStorage.create options
        @storage = @createStorage filename, @options


    @create: (options) ->
        return new Blacklist options

    createStorage: (filename, options)->
        modpath = "./#{filename}"
        if require.resolve(modpath)
            mod = require(modpath)
            return mod.create options
        return undefined

    # get refresh count for client
    getRefreshCount: (clientId, cb) ->
        @storage.getRefreshCount clientId, cb

    # inc refresh count for client
    incrementRefreshCount: (clientId, cb) ->
        @storage.incrementRefreshCount clientId, cb

    # whether clientId is revoked
    getRevokedClientId: (clientId, cb) ->
        @storage.getRevokedClientId clientId, cb

    # whether pushId is revoked
    getRevokedPushId: (pushId, cb) ->
        @storage.getRevokedPushId pushId, cb

    # add revoked clientId
    revokeClientId: (clientId, cb) ->
        @storage.revokeClientId clientId, 'no reason', cb

    # add revoked pushId and the clientId it associates
    revokePushId: (pushId, clientId, cb) ->
        @storage.revokePushId pushId, clientId, 'no reason', cb

module.exports.Blacklist = Blacklist
