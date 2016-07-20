var assert = require('assert')

//
// either module.exports, or exports.Funcs = ...
//
module.exports = {
    assertStatus : function(code) {
        return function(err, res, body) {
            assert.equal(res.statusCode, code);
        }
    },

    assertJsonHead : function() {
        return function(err, res, body) {
            assert.equal(res.headers['content-type'], 'application/json');
        }
    },

    assertValidJson : function() {
        return function(err, res, body) {
            bodyJson = JSON.parse(body)
            assert.isObject(bodyJson);
        }
    },

    assertResValue : function(val) {
        return function(err, res, body){
            assert.include(body, val);
        }
    }
};
