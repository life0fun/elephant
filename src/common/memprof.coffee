#
# Mem profiler
# -----------
#

fs = require('fs')
path = require('path')
url = require 'url'
EventEmitter2 = require('eventemitter2').EventEmitter2
memwatch = require('memwatch')

Logging = require('../common/logging')

#
# temparorily use node module memwatch until we find better ones.
# we found that node-webkit-agent is more powerful  We switch to use it.
#   https://github.com/c4milo/node-webkit-agent
#

class MemProf

    logger = Logging.getLogger "memprof"

    constructor: (@server) ->
        # event name can be wildcard matched, or namespace matched.
        @ee = new EventEmitter2 wildcard: true, delimiter: '?'
        @started = false
        @heapdump = undefined
        @logfile = path.resolve('test', 'perf', 'mem.prof')

    # dep inj the ref to server
    @create : (server) ->
        logger.info 'MemProf : created'
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

    stopHeapDump : (wait) ->
        if @heapdump
            console.log 'memeprof : ending : before gc'
            memwatch.gc()  # perform a gc first
            #gc()

            cb = =>
                console.log 'memprof : ending : process memoryUsage :', process.memoryUsage()
                diff = @heapdump.end()
                console.log(JSON.stringify(diff, null, 2))
                fs.writeFileSync @logfile, JSON.stringify(diff, null, 2)
                @heapdump = undefined
                @started = false

            # wait until gc done before taking heap dump.
            setTimeout cb, wait

    toggleHeapDump : ->
        if not @startHeapDump()
            @stopHeapDump(30000)  # wait 30 seconds until gc done to take diff

exports.MemProf = MemProf
