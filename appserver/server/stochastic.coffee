#!/usr/bin/env coffee

#
# provide stochastic and random intervals during app push tests
#
# currently, we only implemented random interval function 
#

Config = require('../appserverconfig.js')

#
# this module provider interval distribution during app push test.
#
class Stochastic

    constructor: (@seed) ->

    @getVariableLengthString : ->
        sz = Math.ceil(Math.random() * Config.MAX_SIZE)
        return sz

    @getNextSleepInterval: ->
        interval = Math.ceil(Math.random() * Config.MAX_SLEEP)
        return interval

exports.Stochastic = Stochastic

# unit test
unit = ->
    for i in [0..10]
        console.log ' length : ', Stochastic.getVariableLengthString()
        console.log ' interval : ', Stochastic.getNextSleepInterval()
#unit()

