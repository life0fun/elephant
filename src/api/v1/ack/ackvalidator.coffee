#!/usr/bin/env coffee
#

Logging = require('../../../common/logging')

#
# validate push ack request,  remember to return clientId
# If Authorization header does not define client id, return 401 Unauthorized
# If client id was revoked, return 403 Forbidden
# If Content-Type header is invalid, return 415 Unsupported Media Type
# If request content is malformed, return 400 Bad Request
#
# ackInfo: {"pushIndex":"0@1","data":"[ 6 a-2-1 ]"}
#

class AckValidator
    # class static logger
    logger = Logging.getLogger "ack-validator-v1"

    constructor: (@options) ->
        @blacklist = @options.blacklist   # get blacklist from options

    # factory pattern
    @create: (options) ->
        return new AckValidator options
  

    # validate push ack request,  remember to return clientId
    # the passed in ackInfo has the following information
    # ackInfo: {"pushIndex":"0@1","data":"[ 6 a-2-1 ]"}
    validateRequest: (clientId, auth, type, ackInfo, onSuccess, onError) ->

        # populate basic info of validation result
        validateInfo =
            clientId: clientId

        if ackInfo.hasOwnProperty('pushIndex')
            validateInfo.pushTransId = ackInfo.pushIndex
            validateInfo.pushIndex = validateInfo.pushTransId.split('@')[0]

        if ackInfo.hasOwnProperty('data')
            validateInfo.streamIds = ackInfo.data

        # first, simple check of http headers
        if not auth or not clientId
            validateInfo.errMsg = 'unauthorized request'
            onError 401, validateInfo
            return
        else if type and type.indexOf('application/json') < 0
            validateInfo.errMsg = 'unsupported media type'
            onError 415, validateInfo
            statusCode = 200   # Fake for testing
            return

        # malformated content, contains invalid pushIndex or stream ids
        checkAckContent = (ackInfo) ->
            if validateInfo.hasOwnProperty('pushIndex') and
               validateInfo.hasOwnProperty('streamIds')
                validateInfo.result = 'Push Delivered Successfully !!!'
                onSuccess 200, validateInfo
            else
                onError 400, validateInfo  # 400 bad request malformated content

        # callback checking client id is revoked
        # continue to check push id
        onGetRevokeClientId = (err, clientid) =>
            logger.debug 'clientId revoked ? ', clientid
            if clientid
                validateInfo.errMsg = ' clientId revoked: ' + clientid.memo
                onError 403, validateInfo  # forbidden revoked clientid
            else
                checkAckContent ackInfo

        @blacklist.getRevokedClientId clientId, onGetRevokeClientId

exports.AckValidator = AckValidator

