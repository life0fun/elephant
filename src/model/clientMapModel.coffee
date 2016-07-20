#!/usr/bin/env coffee


#
# this file defines clientmap data model.
#

Sequelize = require('sequelize')

class ClientMapModel

    @tableName = 'connected_push_id'
    
    @schema =
        pushid: {
            type: Sequelize.STRING, 
            primaryKey: true, 
            allowNull: false, 
            comment: "push id"
        }

        clientid: {
            type: Sequelize.STRING, 
            unique: true,       # create unique index
            allowNull: false, 
            comment: "client id"
        }

        hostname: {
            type: Sequelize.STRING, 
            allowNull: false, 
            comment: "hostname:port"
        }

        workerid: {
            type: Sequelize.STRING, 
            allowNull: false, 
            comment: "spdy worker id"
        }

        timestamp: {
            type: Sequelize.DATE, 
            allowNull: false, 
            comment: "timestamp"
        }



# define the model and export it
module.exports = (sequelize, DataTypes) ->
    return sequelize.define ClientMapModel.tableName, 
                            ClientMapModel.schema,
                            {freezeTableName: true}

