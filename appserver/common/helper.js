var fs = require('fs');
var path = require('path');

//
// for...in loop in javascript is diff than coffeescript.
// js when you do for i in [], i is idx
// coffeescript when you do for i in [], i is the item in the list, not the idx
//

// deep copy a value.
exports.deepCopy = function(o) {
    // deep copy pass in value by checking if the value is primitive or an object reference.
    // http://stackoverflow.com/questions/103598/why-was-the-arguments-callee-caller-property-deprecated-in-javascript

    // for primitive value, simple copy. For object ref value, need recursively copy
    var copy = o;
    if(o && typeof o === 'object'){
        copy = Object.prototype.toString.call(o) === '[object Array]' ? [] : {};
        for(var k in o){
            if(o.hasOwnProperty(k)){
                //copy[k] = arguments.callee(o[k]);
                copy[k] = exports.deepCopy(o[k]);  // recursive copy the prop of an obj.
            }
        }
    }
    return copy;
};

// pass in value of an object
exports.copyObjectPrimitives = function(o) {
    // deep copy a object with object reference
    // http://stackoverflow.com/questions/103598/why-was-the-arguments-callee-caller-property-deprecated-in-javascript
    var copy = {};
    for(var k in o){
        if(o.hasOwnProperty(k)){
            if( typeof o[k] !== 'object'){
                //copy[k] = arguments.callee(o[k]);
                copy[k] = o[k];
            }
        }
    }
    return copy;
};
