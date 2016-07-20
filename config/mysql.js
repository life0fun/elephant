//
// this is the configuration for sequelize mysql database connections.
//
// Important notes about connection pool settings
// 
// connection pool creates a pool of connection objects to mysql server.
//
// mysql server variable wait_timeout controls the number of seconds the server waits 
// for activity on a connection before closing it. The default value is 28800, 8 hours.
// Mysql server will drop idle connection after 8 hours without activities.
//      show global variables like 'wait_timeout'
//      set global wait_timeout=28800
//
// Sequelize uses generic-pool to manage connection pool to mysql server.
// there are two arguments control the behavior of connection pooling.
//   idleTimeoutMillis - Delay in milliseconds after the idle items in the pool will be 
//                       destroyed.
//   refreshIdle - Should idle resources be destroyed and recreated every 
//                 idleTimeoutMillis? Default: true
//
// so if sequelize connection pool manager does not refresh connections to mysql server, 
// connections will be dropped by mysql server and we will see connection lost error.
//   {[Error: Connection lost: The server closed the connection.] 
//     code: 'PROTOCOL_CONNECTION_LOST' }
// 
// To verify this, set mysql wait_timeout to a small value, 10 seconds, 
// when setting sequelize maxIdleTime bigger than 10 seconds, spdy server will get
//  connection lost error.
// when setting maxIdleTime smaller than 10 seconds, no conection lost error.
//
//


module.exports = {
    storage: require('sequelize-mysql').sequelize,  // db storage for sequelize wrapper
    database: 'spdyclient',
    user: 'elephant',
    password: 'elephant',
    options: {
        host: 'localhost',
        logging: false,
        dialect: 'mysql',
        pool: {
            maxConnections: 12,
            maxIdleTime: 10*60*1000    // refresh mysql connection every 10 min
        }
    }
};
