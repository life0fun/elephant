os = require('os')
StatsD = require('node-statsd').StatsD

Config = require('../config/config')


###
# build statsd options from configuration.
###
getStatsdOptions = ->
    
    config = Config.getConfig "STATSD"
    return {
        host: config.host
        port: config.port
        prefix: "#{config.deployment}.#{os.hostname()}.elephant."
    }

###
# create a statsd client.
###
getClient = ->

    new StatsD getStatsdOptions()


exports.getClient = getClient
