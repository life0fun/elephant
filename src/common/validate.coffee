async = require('async')
Config = require('../config/config')
BasicAuth = require('../common/basicauth')
{PushId} = require('../model/clientpushid')


class Validate

    ###
    # Allow only spdy clients.
    ###
    @isSpdy: (req) ->

        forceSpdyClients = Config.getConfig 'FORCE_SPDY_CLIENT'
    
        (next) ->

            if forceSpdyClients and not req.isSpdy
                next Error.http 400, "Server supports only SPDY clients"
            else
                next null

    ###
    # check that request http method is supported.
    # @param {Request} req
    # @param {List} methods
    # @returns {Function} if the method is supported.
    ###
    @isMethodSupported: (req, methods) ->

        (next) ->

            if req.method in methods
                next null
            else
                next Error.http 405, "Method '#{req.method}' not supported, only #{methods}"

    @isPost: (req) -> @isMethodSupported req, ["POST"]
    @isGet: (req) -> @isMethodSupported req, ["GET"]

    ###
    # Check that the content-type is 'application/json'.
    ###
    @isJson: (req) ->

        (next) ->

            contentType = req.headers['content-type']
            if not contentType or contentType.indexOf("application/json") < 0
                next Error.http 415, "content-type must be 'application/json'"
            else
                next null

    ###
    # Check that request accepts 'application/json'.
    ###
    @acceptsJson: (req) ->

        (next) ->

            accept = req.headers['accept']
            if accept and accept.indexOf("application/json") < 0
                next Error.http 406, "must accept 'application/json'"
            else
                next null

    ###
    # Parse the json body from the request.
    ###
    @parseJson: (req) ->

        (next) ->

            body = ''

            req.on 'data', (data) ->
                body += data

            req.once 'end', ->
                try
                    req.body = JSON.parse body
                    next null
                catch error
                    next Error.http 400, "Invalid json: #{error.message}"

    ###
    # Parse basicauth value without decoding.
    ###
    @_parseBasicAuth: (req) ->

        (next) ->

            auth = req.headers['authorization']
            if not auth
                return next Error.http 401, "missing authorization header"

            match = /Basic\s+(.+)/.exec auth
            if not match
                return next Error.http 401, "bad authorization header"

            req.params.basicAuth = match[1]
            next null

    ###
    # internal validator of username/password.
    ###
    @_validateBasicAuth: (req, credentials) ->

        (next) ->

            [user, pass] = BasicAuth.decode(req.params.basicAuth)
            if user not of credentials or credentials[user] isnt pass
                return next Error.http 401, "bad credentials"
            next null

    ###
    # Validates that username/password is permitted.
    ###
    @validateBasicAuth: (req, credentials) ->

        async.compose @_validateBasicAuth(req, credentials), @_parseBasicAuth(req)

    ###
    # Validates that client username/password is permitted.
    ###
    @validateClientBasicAuth: (req) ->
    
        @validateBasicAuth req, Config.getConfig "REGISTER_AUTH"

    ###
    # Validates that app username/password is permitted.
    ###
    @validateAppBasicAuth: (req) ->
    
        @validateBasicAuth req, Config.getConfig "AUTH"

    ###
    # internal parse client id from request auth header.
    ###
    @_parseClientId: (req) ->

        (next) ->

            req.params.clientId = req.params.basicAuth
            next null

    ###
    # parse the client id from the request authorization header.
    ###
    @parseClientId: (req) ->

        async.compose @_parseClientId(req), @_parseBasicAuth(req)


    @validateRevokedClientId: (req) ->

        (next) ->

            req.app.blacklist.getRevokedClientId req.params.clientId, (err, revokedClient) ->

                if err
                    next Error.http 500, "internal DB error", {}, err
                else if revokedClient?
                    next Error.http 403, "client id revoked"
                else
                    next null

    ###
    # validate that push id matches client id.
    ###
    @validatePushId: (req) ->

        (next) ->

            req.app.blacklist.getRefreshCount req.params.clientId, (err, count) ->

                if err
                    return next Error.http 500, "internal DB error", {}, err
                
                # validate push id against expected generated push id
                genPushId = PushId.generatePushId req.params.clientId, count
                if req.params.pushId isnt genPushId and process.env.NODE_ENV isnt 'unit'
                    return next Error.http 401, "invalid push id", {
                        pushId: req.params.pushId
                        expectedPushId: genPushId
                    }
                
                next null

    ###
    # check that push id wasn't revoked.
    ###
    @validateRevokedPushId: (req) ->

        (next) ->

            req.app.blacklist.getRevokedPushId req.params.pushId, (err, revokedPushId) ->

                if err
                    next Error.http 500, "internal DB error", {}, err
                else if revokedPushId?
                    next Error.http 410, "push id revoked"
                else
                    next null


module.exports = Validate
