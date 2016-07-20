#
# A stream buffer
# wraps data buffering logic for request that data chunk
#

net = require('net')
util = require('util')
Node = require('../common/root')

# A stream Buffer that buffers stream data from incoming stream request
class ReqBuffer

    # dep inj req object, augment it
    constructor : (@req, @name, @onDataEnd, @onChunk) ->
        @buffers = []      # all buffers in the array
        @datalen = 0
        ended = false

        # data chunk
        @req.on 'data', (chunk) =>
            #if typeof @onChunk is 'function'
            #    @onChunk chunk
            @buffers.push chunk

        # data done, one end, not close
        @req.on 'end', =>
            ended = true
            data = @combineChunks()
            Node.logInfo 'ReqBuffer on end data :', @name, data
            if typeof @onDataEnd is 'function'
                @onDataEnd data

    # factory
    @create : (req, name, onDataEnd) ->
        return new ReqBuffer req, name, onDataEnd

    # combine all data chunks and notify app
    combineChunks : ->
        @datalen = 0
        for chunk in @buffers
            @datalen += chunk.length

        @buffer = new Buffer(@datalen)

        # now copy each chunk into buffer
        offset = 0
        for chunk in @buffers
            chunk.copy @buffer, offset
            offset += chunk.length

        # utf-8 encoding
        return @buffer.toString()


exports.ReqBuffer = ReqBuffer
