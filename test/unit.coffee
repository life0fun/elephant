#!/usr/bin/env coffee

spawn = require('child_process').spawn

#
# a wrapper to execute spdycli for unit test
#

class ElephantUnit
    # class sharable global
    cmd = './spdycli'

    args = []
    args.push '-u'
    args.push '-l'
    args.push '-n 1'
    args.push '-v'

    options = {}
    options.cwd = 'client/aws'
    options.env = {}
    options.env['LD_LIBRARY_PATH'] = '.'

    constructor: ->
        console.log 'should not instantiate this object.'

    @cpArgs : ->
        newargs = []
        for e in args
            newargs.push e 
        return newargs

    @testListenGood : (cb) ->
        testArgs = @cpArgs()
        testArgs.push '-p'
        result = spawn cmd, testArgs, options
        result.stdout.on 'data', (data) ->
            if data
                msg = data.toString()
                sidx = msg.indexOf('{"statusCode":')
                if sidx >= 0
                    eidx = msg.lastIndexOf('}')
                    msjobjstr = msg.substring(sidx, eidx+1)
                    cb msjobjstr

    @testUnAuthListen : (cb) ->
        testArgs = @cpArgs()
        testArgs.push '-p'
        testArgs.push '-a'
        result = spawn cmd, testArgs, options
        result.stdout.on 'data', (data) ->
            if data
                msg = data.toString()
                sidx = msg.indexOf('{"statusCode":')
                if sidx >= 0
                    eidx = msg.lastIndexOf('}')
                    msjobjstr = msg.substring(sidx, eidx+1)
                    cb msjobjstr

    @testRefreshGood : (cb) ->
        testArgs = @cpArgs()
        testArgs.push '-s'   # refresh as s
        result = spawn cmd, testArgs, options
        result.stdout.on 'data', (data) ->
            if data
                msg = data.toString()
                sidx = msg.indexOf('{"statusCode":')
                if sidx >= 0
                    eidx = msg.lastIndexOf('}')
                    msjobjstr = msg.substring(sidx, eidx+1)
                    cb msjobjstr

exports.ElephantUnit = ElephantUnit

# unit test 
#ElephantUnit.testListenGood( (data) -> console.log data)
