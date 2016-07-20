#!/usr/bin/env coffee

#
# Persistent layer interface object
#
# All persistent storage object must implement all the functions
# defined in this interface object, so that the user of storage object
# knows function name.
#

#
# Interface as an object
# No-op functions.
# Implementor must overwrite the function
#

# Note that we have to use module pattern to return object,
# not overwrite return exports object directly.
# this is b/c direct returned exports object is shared to all requires.
# while module pattern return a closusre and executing closure gives
# a new object not sharable across different requires.
#
# usage: interfaceobj = require(./interface)()
#
module.exports = ->

    add : (pushId, clientId, serverId, workerId, cb) ->
        throw new Error('not implemented')

    remove : (pushId, cb) ->
        throw new Error('not implemented')

    removeByClientId : (clientId, cb) ->
        throw new Error('not implemented')

    purge: (cb) ->
        throw new Error('not implemented')

    getNumClients : ->
        throw new Error('not implemented')

    getClient : (pushId, cb) ->
        throw new Error('not implemented')

    getAllClients : (cb) ->
        throw new Error('not implemented')

    dumpClients: (filename) ->
        throw new Error('not implemented')

    update : (clientId, valueObj, cb) ->
        throw new Error('not implemented')
