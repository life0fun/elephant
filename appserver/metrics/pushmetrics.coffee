#
# Metrics constant definition
# -----------


assert  = require('assert')

#
# constant value for elephant server metrics
#
# if you want to expose both pub var and pub func,
# they must group together at the end so coffeescript
# can recognize it to return.
#
# module.exports = class PM
#   @Foo : 'bar'
#   @define : (name, value) ->
#       Object.defineProperty(exports, name,
#           { value : value, enumerable : true})
#
module.exports = PushMetrics = do ->
    #metrics = {}    # dict to store all of the metrics

    # section of object private var
    # foo = 'bar'

    # section with object public var and funcs
    # all the default metrics
    app_push_req : 'app_push_req'
    client_push_ack : 'client_push_ack'
    client_register : 'client_register'
    client_listen : 'client_listen'
    client_connect : 'client_connect'
    client_dur : 'client_dur'
    client_ping : 'client_ping'

#
# unit test
#pm = require('./pushmetrics.coffee')
#console.log ' constant SPDY_REQ :', pm.get('SPDY_REQ')
