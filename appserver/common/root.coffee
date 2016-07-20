#
# the root of all function objects
#
fs = require('fs')
path = require('path')
EventEmitter = require('events').EventEmitter
config = require('../config/config')
log4js= require('log4js')

#
# node-config will read the config file under NODE_CONFIG_DIR in some order
# the result is config object and code can ref to it.
#
class Node extends EventEmitter
    log4js.configure({
        appenders: [
            { type : 'console' },

            { type : 'file', \
              filename: '/var/log/elephant/apppush.log', \
              maxLogSize: 100*1024*1024
            }
        ]
    });

    logger = log4js.getLogger('ELE')   # tag is ele

    constructor: (@client) ->

    @log: (msg, extra...) ->
        if config.getConfig('DEBUG_LOG')
            #console.log msg, extra...
            logger.debug(msg, extra...)

    @logError: (msg, extra...) ->
        logger.error(msg, extra...)

    @logFatal: (msg, extra...) ->
        logger.fatal(msg, extra...)

    @logInfo : (msg, extra...) ->
        if config.getConfig('DEBUG_LOG')
            logger.info(msg, extra...)

    @logWarn : (msg, extra...) ->
        if config.getConfig('DEBUG_LOG')
            logger.warn(msg, extra...)

    @logFile : (msg, extra...) ->
        logger = log4js.getLogger('Push')
        logger.info(msg, extra...)

# shared global, the num of connections
Node.numConns = {}

module.exports = Node
