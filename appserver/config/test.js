//
// This is the configuration for node server running
// under test environ.
// section is picked up by setting proper NODE_ENV
// to set this env, do
//   export NODE_ENV=test
//
module.exports = {
    HTTP_PORT : 9081,
    SSL_PORT : 9443,
    WORKERS : 1,
    DEBUG_LOG : true,
    SERVER_PUSH : true
};
