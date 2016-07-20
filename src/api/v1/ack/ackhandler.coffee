#!/usr/bin/env coffee

#
# Ack V1 Api request handler
# logic for handling client ack of push request
#
#

Logging = require('../../../common/logging')
HeaderParser = require('../../headerparser')    # parse http header
AckValidator = require('./ackvalidator').AckValidator

#
# client Ack request handler
#
# handle client push ack, ack information in http post data
# client post data passed in as socket data event,
# not in req.on data event.
#
# Require client ack data echo back the push transaction id.
# This is needed b/c on server side, the transaction id is used to id into
# pending server push list to find the associated pending server push request.
#
# We not using stream id because stream id is allocated last minute when data
# got pushed out from the server. Because we need to allocate cache for push
# request in push list up front before push data to the client; hence stream id
# is too late to be used for the purpose of associating push request.
#
# XXX spdy stream header FRAME and data FRAME comes in as
# two separate data event b/c server do two calls writeHead and end
#
# Note we do not have pushId here, only clientId and pushIndex, transaction id.
# push ack: {"pushIndex":"0@1","data":"[ 6 a-2-1 ]"}
#
class AckHandler
    # class variable, to avoid this ref if declared as instance var.
    logger = Logging.getLogger "ack-v1"

    constructor: (@options) ->
        @validator = AckValidator.create @options  # init validator

    # factory pattern
    @create: (options) ->
        return new AckHandler options

    toString: ->
        return 'AckHandler : ' + @options


    #
    # handle ack request from client that acks a previous push
    # ackInfo: {"pushIndex":"0@1","data":"[ 6 a-2-1 ]"}
    #
    handleRequest: (req, onRequestProcessed) ->

        type = HeaderParser.getContentType req
        auth = HeaderParser.getAuth req
        clientId = HeaderParser.getClientId req

        # client ack request has error, 401, 415, or 403
        onError = (statusCode, errInfo) ->
            # on error case, errInfo has clientId
            logger.warn 'handle client pushack error:', JSON.stringify errInfo
            onRequestProcessed statusCode, errInfo

        # validation on Successfully
        onSuccess = (statusCode, validateInfo) ->
            logger.info 'handle client pushack :', JSON.stringify validateInfo
            onRequestProcessed statusCode, validateInfo

        # post req data is comming in from socket data event,
        # XXX spdy stream header FRAME and data FRAME comes in as two separate
        # data event; hence on two data events with data FRAME later.
        req.socket.on 'data', (data) =>
            ackData = data.toString()   # should be a json obj
            logger.debug 'client push ack : ', ackData
            # stream header FRAME and data FRAME as separate data event.
            if ackData.indexOf('pushIndex') >= 0
                # ackInfo: {"pushIndex":"0@1","data":"[ 6 a-2-1 ]"}
                ackInfo = JSON.parse ackData
                @validator.validateRequest clientId, auth, type, ackInfo,
                                           onSuccess, onError

exports.AckHandler = AckHandler
