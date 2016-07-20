//
//
// This is the default configuration for elephant.
// It is always loaded and overridden by a deployment.EXT config file.
// To set a deployment/environment, do
//   export NODE_ENV=development  # or 'production' or any other deployment
//

retryPolicy = require('./retrypolicy.js');
statsd = require('./statsd.js');
auth = require('./basicauth.js');
keys = require('./keys.js');
regAuth = require('./registerauth.js');
winston = require('winston');
moment = require('moment');

/**
 * Timestamp formatter for log messages.
 */
function timestamp(ts) {
    return moment(ts).format("YYYY-MM-DD HH:mm:ss.SSS");
}

module.exports = {
    APP_PORT: 8443,
    SPDY_PORT: 9443,
    FORCE_SPDY_CLIENTS: true,
    WORKERS: 4,
    DEBUG_LOG: false,
    LOG_LEVEL: "info",          // silly, debug, verbose, info, warn, error
    REVOKE_API_ENABLED: false,
    PUSH_TIMEOUT: 4,            // push request timeout, in seconds
    DISPATCH_TIMEOUT: 3000,     // push request dispatch timeout, in milliseconds
    STORAGE: 'mysqlclientmap',  // persistent storage layer for client info
    PUSH_STORAGE: 'mysqlpushrequest',   // must have corresponding file at persistent layer
    SALT: 'elephant',
    DB: require('./mysql.js'),
    MIN_SOCKET_TIMEOUT_SEC: 1200,     // min client socket timeout value, default 1200, 20mins.
    SERVER_PUSH_URL: '/api/client/ack',
    MAX_SOCKETS: 1000000,       // http global agent max sockets.
    PUSH_CALLBACK_RETRIES: 2,
    EXIT_ON_CLIENT_ERROR: true,
    REGISTER_AUTH: regAuth,
    RETRY_POLICY: retryPolicy,
    STATSD: statsd,
    AUTH: auth,
    KEYS: keys,
    MEM_WATCH: false,
    UNIT_TEST: false,
    AES_KEY: 'elephant',         // the same as salt
    HEAPDUMP: '/var/log/elephant/heapdump-',  // heapdump snapshot file prefix
    LOGGING: {
        default: function(name) {
            return {
                transports: [
                    new (winston.transports.Console)({
                        colorize: true,
                        level: 'debug',
                        timestamp: timestamp,
                        label: name
                    })
                ]
            };
        }
    }
};
