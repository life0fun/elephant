#!/usr/bin/env coffee


#
# this file defines revoked push id data model.
#

Sequelize = require('sequelize')

# this class defines the schema used to store connected client information.
class RevokedPushIdModel

    @tableName = 'revoked_push_id'
    
    @schema =
        pushid: {
            type: Sequelize.STRING, 
            primaryKey: true, 
            allowNull: false, 
            comment: "push id"
        }
        
        clientid: {
            type: Sequelize.STRING, 
            unique: true, 
            allowNull: false, 
            comment: "client id"
        }
        
        timestamp: {
            type: Sequelize.DATE, 
            allowNull: false, 
            comment: "timestamp"
        }
        
        memo: {
            type: Sequelize.TEXT, 
            allowNull: false, 
            comment: "revoke memo"
        }


# define the model and export it
module.exports = (sequelize, DataTypes) ->
    return sequelize.define RevokedPushIdModel.tableName, 
                            RevokedPushIdModel.schema,
                            {freezeTableName: true}

