#!/usr/bin/env node

//
// simulated server main
//
// accept as input the server URL and the number of available clients
// Stochastically submit variable length push message to clients
//
// log every request/response for subsequent analysis
//

require('coffee-script');
var EventEmitter = require('events').EventEmitter;
var AppServer = require('./server/appserver').AppServer;

// process.argv is an array containing cmd line args. 0th is node.
main = function() {
  var options = {};
  options['pushVer'] = 'v2';
  if(process.argv.length > 2){
    options['pushVer'] = process.argv[2];
  }

  AppServer.create(options);
};

process.on('SIGINT', function () {
    console.log('supervisor asks to stop, exit now !!!');
    process.exit(1);
});

process.on('uncaughtException', function (err) {
    console.log('elephant exception :', err);
    console.log(err.stack);
    process.exit(1);
});

module.exports = main;

// let the show start !
main();
