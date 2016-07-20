//
// This is the configuration for node server running
// under test environ.
// section is picked up by setting proper NODE_ENV
// to set this env, do
//   export NODE_ENV=test
//
module.exports = {
    "server_errors": {
      "interval_millis": 800,
      "exponential_factor": 1.6,
      "max_retries": 10
    },
    "client_errors": {
      "interval_millis": 200,
      "exponential_factor": 1.7,
      "max_retries": 50
    }
};