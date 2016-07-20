#
# data processing logic of incomingMessage
#

net = require('net')
util = require('util')

# just expose this one function
module.exports = {
    # data is a string, already converted from Buffer inside on data event.
    processMessage : (data, cb) ->
        # console.log('handle socket data :', data)
        if data.length > 0
            msgobj = JSON.parse(data)
        else
            msgobj = {}
            msgobj.name = 'clid-default'

        idx = data.indexOf('\\A')  # msg delimiter, simulated
        if(idx >= 0)
            body = JSON.parse(data.substring(0,idx))
            # console.log( 'processing data : ', JSON.stringify(body))
            cb 'From server: how are you today ? '+ body['name']

        replyobj = {}
        replyobj.msg = 'from server: how are you doing ?' + msgobj.name
        cb msgobj.name, replyobj

}
