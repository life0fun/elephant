#
# Common helper util functions.
#

{Crypto} = require('cryptojs')

Config = require('../config/config')

###
# deep copy pass in value by checking if the value is primitive or an object
# reference.
# http://stackoverflow.com/questions/103598/
# why-was-the-arguments-callee-caller-property-deprecated-in-javascript
###
exports.deepCopy = (o) ->
    
    # for primitive value, simple copy. For object ref value, need recursively copy
    copy = o

    # if o is object, not primitive, copy each prop
    if o and typeof o is 'object'
        copy = if Object.prototype.toString.call(o) is '[object Array]' then [] else {}
        for k of o
            if o.hasOwnProperty k
                copy[k] = exports.deepCopy o[k]  # recursive copy the props
    return copy


exports.copyObjectPrimitives = (o) ->
    copy = {}
    for k of o
        if o.hasOwnProperty k
            if typeof o[k] isnt 'object'
                copy[k] = o[k]
    return copy


###
# get the ip addr of this host
###
exports.getLocalhostIp = (onFoundIp) ->
    hostname = require('os').hostname()
    require('dns').lookup hostname, (err, addr, fam) ->
        if typeof onFoundIp is 'function'
            onFoundIp addr


###
# encrypt text with AES.
###
exports.aesEncrypt = (cleartext) ->
    if cleartext?
        key = Config.getConfig 'AES_KEY'
        enctext = Crypto.AES.encrypt cleartext, key
        return enctext


###
# decrypt text with AES.
###
exports.aesDecrypt = (enctext) ->
    if enctext?
        key = Config.getConfig 'AES_KEY'
        cleartext = Crypto.AES.decrypt enctext, key
        return cleartext


###
# return the elephant package version.
###
exports.getVersion = ->
    require('../../package.json').version
