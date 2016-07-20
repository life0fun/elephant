#!/usr/bin/env coffee

#
# abstract persistent layer for client information persistent and look up
# populate persistent object with all supporting methods.
# currently support local object hashmap and mysql
#

net = require('net')
util = require('util')


#
# index object as a func wrapper. require execute it
#
module.exports = ->
    storages = {}
    supportedMethods = ['objectclientmap', 'mysqlclientmap']

    load : ->
        output = {}
        for m in supportedMethods
            modpath = "./#{m}"   # intrapolate need double quote
            if require.resolve(modpath)
                mod = require(modpath)
                storages[m] = mod

        return storages

    # create an instance of storage layer
    create : (name) ->
        return storages[name].create()


