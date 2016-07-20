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

    @SOCKET_NOT_WRITABLE = 'SOCKET_NOT_WRITABLE'    # not res.writable
    @SOCKET_CLOSED = 'SOCKET_CLOSED'                # socket closed event
    @PUSH_ID_NOT_EXIST = 'PUSH_ID_NOT_EXIST'        # push id does not exist
    @CLIENTID_REVOKED = 'CLIENTID_REVOKED'          # clientid revoked
    @PUSHID_REVOKED = 'PUSHID_REVOKED'              # pushid revoked
    @MYSQL_ERROR = 'MYSQL_ERROR'                    # mysql error

    # can not find session on spdy server for client id
    @CLIENT_SESSION_NOT_EXIST = 'CLIENT_SESSION_NOT_EXIST'

    # server push stream error when calling res.push
    @PUSH_STREAM_ERROR = 'PUSH_STREAM_ERROR'

    # push timed out error
    @PUSH_TIMED_OUT = 'PUSH_TIMED_OUT'

    constructor: (@type, @msg, @file, @func, @errObj) ->
        if not @errObj
            @errObj = new Error(@msg, @file, @func)
        Error.captureStackTrace this, 'ELE'

    @create : (type, msg, file, func) ->
        new ElephantError type, msg, file, func

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
