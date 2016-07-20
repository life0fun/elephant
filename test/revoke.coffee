https = require('https')
Config = require('../src/config/config')


###
# use elephant api to revoke a client ID.
#
# @param {string} clientId - client id to revoke.
# @param {function} done - revoke callback accepting error and response arguments.
###
revokeClientId = (clientId, done) ->

    options =
        host: 'localhost'
        port: Config.getConfig('APP_PORT')
        method: 'POST'
        rejectUnauthorized: false
        path: '/admin/v1/revokedClientId'
        headers:
            "Content-Type": "application/json"

    body =
        clientId: clientId

    req = https.request options, (res) ->
        done null, res
    
    req.on 'error', (err) ->
        done(err)

    req.end(JSON.stringify body)


###
# use elephant api to revoke a push ID.
#
# @param {string} clientId - client id of push id to revoke.
# @param {string} pushId - push id to revoke.
# @param {function} done - revoke callback accepting error and respons arguments.
###
revokePushId = (clientId, pushId, done) ->

    options =
        host: 'localhost'
        port: Config.getConfig('APP_PORT')
        method: 'POST'
        rejectUnauthorized: false
        path: '/admin/v1/revokedPushId'
        headers:
            "Content-Type": "application/json"

    body =
        clientId: clientId
        pushId: pushId

    req = https.request options, (res) ->
        done null, res
    
    req.on 'error', (err) ->
        done(err)

    req.end(JSON.stringify body)


module.exports =
    revokeClientId: revokeClientId
    revokePushId: revokePushId
