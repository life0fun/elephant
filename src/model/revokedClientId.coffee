#!/usr/bin/env coffee


#
# this file defines data model for revoked client id.
#

Sequelize = require('sequelize')

class RevokedClientIdModel

    @tableName = 'revoked_client_id'
    
    @schema =
        clientid: {
            type: Sequelize.STRING, 
            primaryKey: true, 
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
    return sequelize.define RevokedClientIdModel.tableName, 
                            RevokedClientIdModel.schema,
                            {freezeTableName: true}

