#
# configuration wrapper.
#

config = require('config')

#
# node-config will read and merge configuration files under NODE_CONFIG_DIR.
# It will load `default.js` and override it with `${NODE_ENV}.js`.
#
class Config

    @getConfig: (name) ->
        return config[name]

    @dump: ->
        return JSON.stringify config


module.exports = Config
