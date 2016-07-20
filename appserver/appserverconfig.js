//
// This is the configuration for app server
//
module.exports = {
    HTTP_PORT: 9070,
    //PUSH_URL: 'http://elephant-cte.colorcloud.com:8443/application/',
    PUSH_URL: 'https://localhost.colorcloud.com:8443/application/',
    //PUSH_URL: 'http://elephant-dev.colorcloud.com:8443/application/',
    CLIENT_FILE: 'clients.txt',
    DEBUG_LOG: true,
    PUSHALL_INTERVAL : 5000,    // the interval to perform push all
    MAX_PUSH_SIZE : 1024,       // max push size in bytes
    MAX_SLEEP: 5,    // max sleep interval between push requests
    POISSON_LAM: 5,  // the lambda value of poisson distribution.
    TEST_TIME: 20,   // how long in minutes the test should run
    TOTAL_PUSHES: 1000    // how many total pushes should the server generate
};
