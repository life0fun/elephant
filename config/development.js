//
//
// This is the configuration for elephant server running
// under development/local environment.
// To set this env, do
//   export NODE_ENV=development
//

module.exports = {
    WORKERS : 2,
    DEBUG_LOG : true,
    LOG_LEVEL : "silly",  // silly, debug, verbose, info, warn, error
    MAX_SOCKETS : 1000,   // http global agent max sockets.
    REVOKE_API_ENABLED: true
};
