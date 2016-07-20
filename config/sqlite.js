//
// this is the configuration for sqlite database connections.
// Note that this file should be required by unit test only !
//
module.exports = {
    storage: require('sequelize-sqlite').sequelize,  // db storage for sequelize wrapper
    database: 'spdyclient',
    user: 'elephant',
    password: 'elephant',
    options: {
        host: 'localhost',
        logging: false,
        dialect: 'sqlite',
    }
};
