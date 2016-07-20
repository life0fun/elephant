var assert = require('assert');
var asserthelper = require('./asserthelper');
var vows = require('vows');
var request = require('request');
var EventEmitter = require('events').EventEmitter;
var spawn = require('child_process').spawn;
var exec = require('child_process').exec;

var elephant = require('../src/app');

//
// topic is a func to exec a piece of async code, pass result to this.callback.
// vow to assert the result of async code executed by topic
// for async test, topic : () -> my_to_be_tested_func(args, this.callback)
// vow of the topic get args from callback. 'vow topic result: function(err, res, body){ ... }'
//

var test = vows.describe('test server').addBatch({
        'server register test :' : {   // start server context
            topic: function() {
                var promise = new EventEmitter;
                var app = elephant(promise);
                // return the eventEmitter promise, and vow tests will be run only when promise emit success.
                return promise;
            },
            'server started successfully' : function(workerId){
                assert.equal(workerId, 1);
            },
            'test connections api' : {     // nested context for connections api
                topic : function() {    // topic is a func or value which can exec async code
                    request({
                        url : 'http://localhost:8080/connections',
                        method : 'GET',
                        headers : {
                            'content-type' : 'application/json'
                        }
                    }, this.callback);
                },
                'should respond with 200': asserthelper.assertStatus(200),
                'should respond with valid json object': asserthelper.assertValidJson()
            },
            'test api/client/v2 api' : {   // nested context for registration api
                topic : function() {
                    request({
                        url: 'https://localhost:3000/api/client/v2',
                        method: 'GET',
                        requestCert: false,
                        rejectUnauthorized: false,
                        strictSSL : false,
                        headers : {
                            'Content-Type' : 'text/plain'
                        }
                    }, this.callback);
                },
                'should responde 200' : asserthelper.assertStatus(200),
                'should responde with application/json header' : asserthelper.assertJsonHead()
            }
        }
    }).export(module);
