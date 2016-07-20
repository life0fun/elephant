#
# config layer
#
Node = require('../common/root')
config = require('./test')

#
# node-config will read the config file under NODE_CONFIG_DIR in some order
# the result is config object and code can ref to it.
#
class Config extends Node
    constructor: ->
        #process.env.NODE_CONFIG_DIR = './spdy'
        Node.log 'CONFIG_DIR:', process.env.NODE_CONFIG_DIR

    @getConfig: (name) ->
        #Node.log 'get config:', name, process.env.NODE_ENV, config
        return config[name]

module.exports = Config