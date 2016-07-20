#
# Data model for push request.
#

Sequelize = require('sequelize')


class PushRequestModel

    @tableName = "push_requests"
    
    @schema =
        requestId: {
            type: Sequelize.STRING
            comment: "async push requet uuid"
            unique: true
        }
        clientId: {
            type: Sequelize.STRING
            comment: "client Id"
        }
        pushId: {
            type: Sequelize.STRING
            comment: "push Id"
        }
        serverId: {
            type: Sequelize.STRING
            comment: "server Id"
        }
        workerId: {
            type: Sequelize.STRING
            comment: "worker Id"
        }
        callbackUrl: {
            type: Sequelize.STRING
            comment: "callback url"
        }
        callbackUsername: {
            type: Sequelize.STRING
            comment: "callback username"
        }
        callbackPassword: {
            type: Sequelize.STRING
            comment: "callback password"
        }
        startTime: {
            type: Sequelize.DATE
            comment: "push start timestamp"
        }

    @getterMethods:

        # expose a 'pushIndex' attribute
        pushIndex: ->
            @id


# define the model and export it
module.exports = (sequelize, DataTypes) ->
    sequelize.define PushRequestModel.tableName, PushRequestModel.schema, {
        freezeTableName: true
        getterMethods: PushRequestModel.getterMethods
    }
