#
# Data model for the client push id refresh count table.
#

Sequelize = require('sequelize')


class RefreshCountModel

    @tableName = 'refresh_count'
    
    @schema =
        clientid:
            type: Sequelize.STRING
            primaryKey: true
            allowNull: false
            comment: "client id"
        
        count:
            type: Sequelize.BIGINT
            allowNull: false
            defaultValue: 1
            comment: "refresh count"

# define the model and export it
module.exports = (sequelize, DataTypes) ->
    return sequelize.define RefreshCountModel.tableName,
                            RefreshCountModel.schema,
                            { freezeTableName: true }
