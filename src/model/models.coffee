#!/usr/bin/env coffee

#
# This module loads all sequelize models in the model directory.
# and exposes it for upper layer app code to use.
#
# Since v1.5.0 of Sequelize the import is cached, so you won't run into troubles
# when calling the import of a file twice or more often.
#

path = require('path')
SequelizeWrapper = require('../persistence/sequelizewrapper')

sequelize = SequelizeWrapper.create()


models = [
    'clientMapModel'
    'pushRequestModel'
    'revokedClientId'
    'revokedPushId'
    'refreshCount'
]

loadModel = (model) ->
    module.exports[model] = sequelize.import(path.join(__dirname, model))

# load the models
models.forEach loadModel

# exports globals
module.exports.SequelizeWrapper = SequelizeWrapper
module.exports.sequelize = sequelize



