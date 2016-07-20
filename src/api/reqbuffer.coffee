#
# A stream buffer
# wraps data buffering logic for request that data chunk
#


# A stream Buffer that buffers stream data from incoming stream request
class ReqBuffer

    # listen on req.socket
    constructor : (@req, @clientId, @onDataFrame, @onChunk) ->
        @buffers = []      # all buffers in the array
        @datalen = 0
        @ended = false
        @contentlen = parseInt(req.headers['content-length'])

        # post req data is comming in from socket data event,
        # XXX spdy stream header FRAME and data FRAME comes in as two separate
        # data event; hence on two data events with data FRAME later.
        @req.socket.on 'data', (chunk) =>
            #if typeof @onChunk is 'function'
            #    @onChunk chunk
            @buffers.push chunk
            @getData(chunk)

        # data done, one end, not close
        @req.socket.once 'end', =>
            @ended = true
            # already processed each frame inside on data event.
            #chunk = @combineChunks()

    # factory
    @create : (req, clientId, onDataFrame) ->
        return new ReqBuffer req, clientId, onDataFrame

    # clean up everything
    cleanup : ->
        @buffers = []
        @datalen = 0
        @ended = false

    # process data
    getData : (chunk) ->
        data = chunk.toString('utf-8')    # default utf8 encoding

        # this is spdy request header
        if @contentlen > 0 and data.indexOf('POST /client/') >= 0
            return
        # now process spdy data frame
        if typeof @onDataFrame is 'function'
            @onDataFrame data

    # combine all data chunks and notify app
    combineChunks : ->
        @datalen = 0
        for chunk in @buffers
            @datalen += chunk.length

        buffer = new Buffer(@datalen)

        # now copy each chunk into buffer
        offset = 0
        for chunk in @buffers
            chunk.copy buffer, offset
            offset += chunk.length

        # utf-8 encoding
        #return buffer.toString('utf-8')
        return buffer

exports.ReqBuffer = ReqBuffer
