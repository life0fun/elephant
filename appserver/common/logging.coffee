#
# Logger factory module.
#

config = require('../config/config')


###
# Get a Logger instance.
#
# @param {string} name - logger name.
###
getLogger = (name) ->
    options = getLoggerOptions(name)
    return new winston.Logger options


###
# Get logger options from logging configuration.
#
# @param {string} name - logger name.
###
getLoggerOptions = (name) ->
    loggingConfig = config.getConfig('LOGGING')

    if loggingConfig.silent
        return {}
    
    loggerOptionsFactory = loggingConfig[name] or loggingConfig['default']
    options = loggerOptionsFactory(name)

    return options


##
# Logger adapter to log application audit messages.
##
class AuditLogger
    constructor: (@logger) ->
    
    ###
    # Add an audit log message.
    #
    # @param {string} event - application event name. required.
    # @param {boolean} succes - event success or error flag. required.
    # @param {int} code - success/error code. optional.
    # @param {string} message - success or error message. optional.
    # @param {dictionary} extra - dictionary of extra fields to log. optional.
    ###
    audit: ({event, success, code, message, extra}) ->
        meta = extra or {}
        meta.event = event
        meta.success = success
        meta.code = code

        @logger.info message or "", meta


###
# Get an AuditLogger instance.
#
# @param {string} name - logger name.
###
getAuditLogger = (name) ->
    logger = getLogger(name)
    return new AuditLogger logger


exports.getLogger = getLogger
exports.getAuditLogger = getAuditLogger
exports.AuditLogger = AuditLogger
