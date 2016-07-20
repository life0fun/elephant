#!/usr/bin/env coffee

# this module contains blacklist validation

Logging = require('../../../common/logging')
{ClientId, PushId} = require('../../../model/clientpushid')
Config = require('../../../config/config')
Q = require('q')   # promise give us back fn composition and error bubbling

#
# Blacklist validator module
# query blacklist db, verify clientId and pushId are not in the database
# in steps. If we found either Id in the blacklist db, the Id is blacklisted,
# we fail the validation in that case.
#

class BlacklistValidator
    # class static for logger, to avoid this ref re-bind
    logger = Logging.getLogger "blacklist"

    constructor: (@blacklist) ->
        logger.info "creating blacklist validator"

    # factory pattern
    @create: (blacklist) ->
        return new BlacklistValidator blacklist

    # fn composition and error bubbling in async world using promise.
    # then() is a fn prop of a promise, it takes fullfill handler and rejection hdl.
    # If promise fullfilled, fullfill hdl called with val.
    # If promise rejected, reject hdl called with the exception.
    # if you ret a val in a hdl, promise will get fullfilled.
    # if you throw an exception, promise will be rejected.
    # if you ret a promise in a hdl, it will chain by replacing the outer promise.
    # use Q nodejs interfacing fns to make promise from callback(err, result).
    #
    # client is an instance of persistence/client, created during validation, contains
    # pushId, clientId, serverId, workerId, if available.
    blacklistValidate: (client, onSuccess, onError) ->
        self = @

        clientId = client.clientId
        pushId = client.pushId

        # check that client id wasn't revoked
        validateClientId = ->

            deferred = Q.defer()

            self.blacklist.getRevokedClientId clientId, (err, revokedClient) ->
                if err
                    logger.error "database error on get revoked client id", {
                        clientId: clientId
                        error: err
                    }
                    deferred.reject new Error JSON.stringify {
                        status: 500
                        msg: "internal DB error"
                    }
                else if revokedClient?
                    logger.info "clientId revoked", {
                        clientId: clientId
                        memo: revokedClient.memo
                    }
                    deferred.reject new Error JSON.stringify {
                        status: 403
                        msg: "client id revoked"
                    }
                else
                    logger.debug "clientId not revoked", { clientId: clientId }
                    deferred.resolve()   # good, fullfill the promise

            deferred.promise
        
        # get refresh cnt, gen pushId, and validate pushId
        validatePushId = ->

            deferred = Q.defer()

            self.blacklist.getRefreshCount clientId, (err, count) ->
                if err
                    logger.error "database error on get refresh count", {
                        clientId: clientId
                        error: err
                    }
                    deferred.reject new Error JSON.stringify {
                        status: 500
                        msg: "internal DB error"
                    }
                    return
                
                logger.debug "client refresh count: #{count}", { clientId: clientId }

                # after we get refresh count, validate push id
                genPushId = PushId.generatePushId clientId, count
                if pushId isnt genPushId and process.env.NODE_ENV isnt 'unit'
                    logger.info "invalid push id", {
                        clientId: clientId
                        pushId: pushId
                        expectedPushId: genPushId
                    }
                    deferred.reject new Error JSON.stringify {
                        status: 401
                        msg: "invlid push id"
                    }
                    return
                
                deferred.resolve()

            deferred.promise

        # check that push id wasn't revoked
        validateRevokedPushId = ->

            deferred = Q.defer()

            self.blacklist.getRevokedPushId pushId, (err, revokedPushId) ->
                if err
                    logger.error "database error on get revoked push id", {
                        pushId: pushId
                        error: err
                    }
                    deferred.reject new Error JSON.stringify {
                        status: 500
                        msg: "internal DB error"
                    }
                else if revokedPushId?
                    logger.info "pushId revoked", {
                        pushId: pushId
                        memo: revokedPushId.memo
                    }
                    # Gone push id revoked
                    deferred.reject new Error JSON.stringify {
                        status: 410
                        msg: "push id revoked"
                    }
                else
                    logger.debug "PushId not revoked", { pushId: pushId }
                    deferred.resolve client

            deferred.promise

        # all promises fullfilled.
        fullfilled = (client) ->
            logger.debug "blacklist promises fullfilled", {
                pushId: client.pushId
            }
            onSuccess 200, client

        # any of the promises got rejected
        rejected = (err) ->
            errmsg = JSON.parse err.message
            onError errmsg.status, errmsg.msg

        validateClientId()
        .then(validatePushId)
        .then(validateRevokedPushId)
        .then(fullfilled)
        .fail(rejected)


# export namespace
exports.BlacklistValidator = BlacklistValidator
