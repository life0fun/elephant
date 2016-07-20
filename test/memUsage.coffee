#!/usr/bin/env coffee


fs = require('fs')
path = require('path')
url = require 'url'
EventEmitter2 = require('eventemitter2').EventEmitter2
memwatch = require('memwatch')

#
# to understand mem usgae
#

class MemUsage

    constructor: ->
        @heapdump = undefined
        @buffer = undefined
        @memStart = undefined
        @memEnd = undefined
        console.log 'understanding mem usage'

    @create : ->
        return new MemUsage()

    prelude : ->
        @memStart = process.memoryUsage()
        @heapdump = new memwatch.HeapDiff()
        console.log '---- mem prelude ----'
        console.log @memStart

    epilogue : ->
        gc()
        @memEnd = process.memoryUsage()
        console.log '---- mem epilogue ----'
        console.log @memEnd
        #diff = @heapdump.end()
        #console.log JSON.stringify diff, null, 2

    testNewBuffer : (sz) ->
        console.log 'testing allocating new buffer size:', sz
        @prelude()
        @buffer = new Buffer(sz)
        @epilogue()
        @buffer = undefined
        #@epilogue()


exports.MemUsage = MemUsage

# unit test 
memUsage = MemUsage.create()
#memUsage.testNewBuffer(100*1000*1000)
memUsage.testNewBuffer(1000)
memUsage.testNewBuffer(1000*1000)
