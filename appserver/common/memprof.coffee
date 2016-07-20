#
# Mem profiler
# -----------
#

fs = require('fs')
path = require('path')
url = require 'url'
EventEmitter2 = require('eventemitter2').EventEmitter2
memwatch = require('memwatch')

Node = require('../common/root')

#
# temparorily use node module memwatch until we find better ones.
#

class MemProf
    constructor: (@server) ->
        # event name can be wildcard matched, or namespace matched.
        @ee = new EventEmitter2 wildcard: true, delimiter: '?'
        @started = false
        @heapdump = undefined
        @logfile = path.resolve('test', 'perf', 'mem.prof')

    # dep inj the ref to server
    @create : (server) ->
        Node.log 'MemProf : created'
        return new MemProf(server)

    # following mem profiling code needs to be in its own module 
    startHeapDump : ->
        console.log 'current heap dump:', @heapdump
        if not @heapdump
            memwatch.gc()   # cause  a gc
            #gc()
            console.log 'memeprof : starting : mem diff....', @heapdump
            console.log 'memeprof : starting : process memoryUsage :', process.memoryUsage()
            @heapdump = new memwatch.HeapDiff()
            @started = true
            return true
        return false

    stopHeapDump : ->
        if @heapdump
            console.log 'memeprof : ending : before gc'
            memwatch.gc()  # perform a gc first
            #gc()

            cb = () =>
                console.log 'memprof : ending : process memoryUsage :', process.memoryUsage()
                diff = @heapdump.end()
                console.log(JSON.stringify(diff, null, 2));
                fs.writeFileSync @logfile, JSON.stringify(diff, null, 2)
                @heapdump = undefined
                @started = false

            setTimeout cb, 30*1000

    toggleHeapDump : ->
        if not @startHeapDump()
            @stopHeapDump()

exports.MemProf = MemProf
