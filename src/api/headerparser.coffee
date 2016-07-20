#!/usr/bin/env coffee

net = require('net')
url = require 'url'
path = require('path')
http = require('http')
qs = require('querystring')
util = require('util')


#
# static functions to parse http headers.
#

# common function to get auth
module.exports.getAuth = (req) ->
    req.headers['authorization']

# common function to get request client id
# The syntax of the authentication header is "Basic <blob>" where blob
# is the base64 encoding of username + ":" + password
# In our case password is the clientId.
module.exports.getClientId = (req) ->
    auth = req.headers['authorization']
    blob = auth.split(/\s+/)[1] if auth
    clientId = blob.trim() if blob

# common function to get request accept header
# accept header may define a charset, be cautious !
module.exports.getAccept = (req) ->
    req.headers['accept']

# common function to get request content type header
module.exports.getContentType = (req) ->
    req.headers['content-type']

# common function to get request length
module.exports.getContentLength = (req) ->
    req.headers['content-length']
