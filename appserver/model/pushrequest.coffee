#!/usr/bin/env coffee

#
# push request manager manages all push requests come from sparkle app server
#

net = require('net')
util = require('util')

Node = require('../common/root')
helper = require('../common/helper')

#
# client id generator
#
class ClientId extends Node
    prefix = 'clid-'
    sequence = 0   # class private var, access directly

    constructor : (options) ->
        @algorithm = options.algorithm
        @key = options.key
        @seed = options.seed

    # factory to generate a push id randomly
    @generateClientId : (workerId, algorithm, key, seed) ->
        if algorithm
            id = algorithm(key, seed)
        else
            sequence += 1
            id = sequence

        clientId = prefix + sequence + '-' + workerId

        Node.log 'clid is :', clientId, sequence
        return clientId

    # clientId format is clid-xxxx
    @isValidClientId : (clientId) ->
        if clientId.substr(0,5) is prefix
            return true
        return false
#
# push id generator and validator
#
class PushId extends Node
    prefix = 'puid-'
    sequence = 0

    constructor : (options) ->
        @algorithm = options.algorithm
        @key = options.key
        @seed = options.seed

    # factory to generate a push id randomly
    @generatePushId : (workerId, algorithm, key, seed) ->
        if algorithm
            id = algorithm(key, seed)
        else
            sequence += 1
            id = sequence

        puid = prefix + id + '-' + workerId
        Node.log 'puid is :', puid, sequence

        return puid

    # pushId format is pid-xxxx
    @isValidPushId : (pushId) ->
        if pushId.substr(0,5) is prefix
            return true
        return false

#
# Each push request close over all the props, including callback url
# and retry counts for acking back to sparkle server.
#
# Each push request is stored into a fixed length array.
# Each push device is lookedup by push Id
#
class PushRequest extends Node
    constructor : (options) ->
        @options = helper.copyObjectPrimitives(options)

        @appRes = options.appRes           # the res to sparkle app server

        @clientId = @options.clientId
        @pushIdx = @options.pushIdx   # the idx in push req list []
        @pushId = @options.pushId
        @transId = @options.transId || 0    # default trans id is 0
        @serverId = @options.serverId
        @workerId = @options.workerId
        @callbackUrl = @options.callbackUrl || '/sparkle/llpush'
        @expiry = @options.expircy
        @status = 'unknown'
        @result = 'unknown'             # status {unknown, pending}
        @sequence = 0
        @reqBody = options.reqBody
        @buffer = new Buffer(0)         # push request body

    # factory pattern
    @create : (options) ->
        return new PushRequest options

    toString : () ->
        return 'pushIdx=' + @pushIdx +  \
                ' pushId=' + @pushId +  \
                ' clientId=' + @clientId +  \
                ' workerId=' + @workerId +  \
                ' serverId=' + @serverId + ' ' + @result + @appRes

    # handle chunk data
    getChunkData : (chunk, cb) ->
        # buffer append: new Buffer, copy existing, append recvd chunk
        # discard the old buffer
        @buffer = new Buffer(0)
        oldBuffer = @buffer
        @buffer = new Buffer oldBuffer.length + chunk.length
        oldBuffer.copy @buffer
        chunk.copy @buffer, oldBuffer.length
        Node.log ' data :' + @buffer.toString()
        cb @buffer.toString()

#
# Push Request Manager manage all push requests from sparkle app server.
# this is the controller, or mediator pattern.
# do we support store and forward ? probably not
#
class PushRequestManager extends Node
    constructor : (options) ->
        @options = options || {}
        @maxPushes = 1000000        # peak push rate wont be 1 m
        @pushRequestList = new Array(@maxPushes)   # 1 million requests
        @pushRequestMap = {}

    # factory pattern
    @create : (options) ->
        return new PushRequestManager options

    ##
    freeSlot : (i) ->
        if typeof @pushRequestList[i] is 'undefined'
            return true
        return false

    ##
    findFreeSlot : () ->
        for i in [0..@maxPushes-1]
            if @freeSlot(i)
                return i
        return -1

    getRequest : (pushIdx) ->
        return @pushRequestList[pushIdx]

    ## find a push req by its clientId
    getRequestByClientId : (clientId) ->
        for i in [0..@maxPushes-1]
            if not @freeSlot(i) and @pushRequestList[i].clientId is clientId
                return i
        return -1

    getPendingRequestsByClientId : (clientId) ->
        return @pushRequestMap[clientId]

    ## find a request by its pushId
    getRequestByPushId : (pushId) ->
        for i in [0..@maxPushes-1]
            if not @freeSlot(i) and @pushRequestList[i].pushId is pushId
                return i
        return -1

    ##
    addPushRequest : (options) ->
        i = @findFreeSlot()
        if i >= 0
            pushRequest = PushRequest.create options
            pushRequest.pushIdx = i
            @pushRequestList[i] = pushRequest
            return pushRequest
        return null

    addPushRequestToMap : (options) ->
        reqs = @getPendingRequestsByClientId options.clientId
        if not reqs
            reqs = []

        pushRequest = PushRequest.create options
        idx = reqs.push pushRequest
        pushRequest.pushIdx = idx-1   # remember the idx
        @pushRequestMap[clientId] = reqs
        return pushRequest

    ## delete a push req entry in the push req list,
    ## which set list entry to undefined.
    deleteRequestByIdx : (i) ->
        if i >= 0 and i < @maxPushes
            delete @pushRequestList[i]

    ##
    deleteRequestByPushId : (pushId) ->
        i = @getRequestByPushId(pushId)
        if i >= 0 and i < @maxPushes
            delete @pushRequestList[i]


exports.ClientId = ClientId
exports.PushId = PushId
exports.PushRequest = PushRequest
exports.PushRequestManager = PushRequestManager

# unit test will be in a separate module.
