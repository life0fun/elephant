//
//
// This is the configuration for node server running
// under unit test environ.
// section is picked up by setting proper NODE_ENV
// to set this env, do
//   export NODE_ENV=unit
//
//

module.exports = {
    FORCE_SPDY_CLIENTS: false,
    WORKERS : 1,
    STORAGE : 'objectclientmap',  // persistent storage layer for client info
    SERVER_PUSH : false,
    UNIT_TEST: true,
    PUSH_TIMEOUT : 10,            // push request timeout, in seconds
    DISPATCH_TIMEOUT: 300,        // push request dispatch timeout, in milliseconds
    DB: require('./sqlite.js'),
    REVOKE_API_ENABLED: true,
    LOGGING: {
        silent: true
    }
};
