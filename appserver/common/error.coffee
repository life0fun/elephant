#
# elephant error types
#
# new Error([String message][, String fileName][, Number lineNumber])
#
fs = require('fs')
util = require('util')

#
# node-config will read the config file under NODE_CONFIG_DIR in some order
# the result is config object and code can ref to it.
#
class ElephantError
    @SOCKET_ERROR = 'SOCKET_ERROR'
    @CLIENT_ID_ERROR = 'CLIENT_ID_ERROR'
    @PUSH_ID_ERROR = 'PUSH_ID_ERROR'
    @APP_PUSH_ERROR = 'APP_PUSH_ERROR'
    @PUSH_NOACK_ERROR = 'PUSH_NOACK_ERROR'

    constructor: (@type, @msg, @file, @func, @errObj) ->
        if not @errObj
            @errObj = new Error(@msg, @file, @func)
        Error.captureStackTrace this, 'ELE'

    @create : (type, msg, file, line) ->
        new ElephantError type, msg, file, line

    toString : ->
        return @type + ':' + @msg + ':' + @file + ':' + @func

    isErrorType : (type) ->
        if @type is type
            return true
        else
            return false

    getErrorType : ->
        return @type

    getStack : ->
        return @errObj.stack

module.exports = ElephantError
