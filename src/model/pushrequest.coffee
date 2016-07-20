#!/usr/bin/env coffee

#
# push request manager manages all push requests come from sparkle app server
#

helper = require('../common/helper')
uuid = require('node-uuid')
Logging = require('../common/logging')

#
# Each push request close over all the props, including callback url
# and retry counts for acking back to sparkle server.
#
# Each push request is stored into a fixed length array.
# Each push device is lookedup by push Id
#
# The clean up of any lingering push request is handled by push time out.
# we are creating requestId from time based UUID.
#
class PushRequest

    constructor: (options) ->
        @options = helper.copyObjectPrimitives(options)

        # the res to sparkle app server if sync push, null if async push
        @appRes = @options.appRes

        @clientId = @options.clientId
        @pushId = @options.pushId
        @pushIndex = @options.pushIndex   # the idx in push req list []
        @requestId = uuid.v1()  # time based UUID to give to sparkle server

        @serverId = @options.serverId
        @workerId = @options.workerId
        
        @callbackUrl = @options.callbackUrl
        @callbackUsername = @options.callbackUsername
        @callbackPassword = @options.callbackPassword
        @msg = options.msg

        @startTime = new Date()

        
        @result = 'unknown'             # status {unknown, pending}
        @sequence = 0
        @buffer = new Buffer(0)         # push request body

    # factory pattern
    @create: (options) ->
        return new PushRequest options

    toString: ->
        return 'pushIndex=' + @pushIndex +  \
                ' pushId=' + @pushId +  \
                ' clientId=' + @clientId +  \
                ' workerId=' + @workerId +  \
                ' serverId=' + @serverId + ' ' + @result

    # handle chunk data
    getChunkData: (chunk, cb) ->
        # buffer append: new Buffer, copy existing, append recvd chunk
        # discard the old buffer
        @buffer = new Buffer(0)
        oldBuffer = @buffer
        @buffer = new Buffer oldBuffer.length + chunk.length
        oldBuffer.copy @buffer
        chunk.copy @buffer, oldBuffer.length
        cb @buffer.toString()

#
# Push Request Manager manage all push requests from sparkle app server.
# this is the controller, or mediator pattern.
# do we support store and forward ? probably not
#
# Important! we support multiple pushes to the same client concurrently
# because each push has its own request id, and has its own unique request id
# and unique index into this pushRequestList. different res object in sync push.
#
# We can handle max 60k concurrent push reqs from server.
# why 60k ? v8 engine largest efficient array is 64k.
# Each request timed out in 10 seconds, so rate is 6k/sec.
# If overflow, we can always grow the list.
# the clean up of stale push request is handled by push time out handler.
#
# If server crashed, both spdy server and app server crashes,
# all data structure cleaned up.
#
class PushRequestManager

    logger = Logging.getLogger "push-manager"

    constructor: (options) ->
        @options = options || {}
       
        # load the push req storage module
        modname = @options.pushStorage || 'mysqlpushrequest'
        
        @storage = @createStorage modname, @options

    # factory pattern
    @create: (options) ->
        return new PushRequestManager options

    # create storage module
    createStorage: (modname, options)->
        modpath = "../persistence/#{modname}"
        logger.info "creating push request storage #{modpath}"
        if require.resolve(modpath)
            mod = require(modpath)
            return mod.create options
        else
            logger.error "storage module missing #{modname}, panic !"
            process.exit(1)  # defined behavior for unexpected case.


    ## delete a push req entry in the push req list,
    ## which set list entry to undefined.
    deletePushRequestByIndex: (pushIndex, done) ->
        @storage.deletePushRequestByIndex pushIndex, done


    # followings are async version.
    getPushRequestByIndex: (pushIndex, onDone) ->
        @storage.getPushRequestByIndex pushIndex, onDone


    addPushRequest: (pushRequest, onDone) ->
        @storage.addPushRequest pushRequest, onDone

    purge: (onDone) ->
        @storage.purge onDone


exports.PushRequest = PushRequest
exports.PushRequestManager = PushRequestManager
