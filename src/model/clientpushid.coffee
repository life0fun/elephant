#!/usr/bin/env coffee

crypto = require('crypto')
Config = require('../config/config')

#
# client id generator
# For testing that requires predicatable ids, each client id must be generated 
# as a URL-safe base64 encoding of a sequential integer starting from zero.
#
#    For example (in Python):
#
#    from base64 import urlsafe_b64encode
#
#    counter = xrange(0, 1000000).__iter__()
#    print urlsafe_b64encode(str(counter.next()))
#
# For everything else, each client id must be generated as a URL-safe base64 
# encoding of a secure random integer using a configurable number of bits 
# (default: 512).
#
#    For example (in Python):
#
#    from base64 import urlsafe_b64encode
#    from os import urandom
#
#    BITS = 512
#    print urlsafe_b64encode(urandom(BITS / 8))
#
#

#
# static factory class, do not instanitate
#
class ClientId
    sequence = 0   # class private var, access directly

    BITS = 512     # configurable num of bit, default to 512

    # For test only. Factory to generate a client id sequentially
    @generateClientIdSeq : (rndSeed) ->
        sequence += 1
        id = sequence

        clientId = id + '-' + rndSeed
        return clientId

    # factory to generate client id
    @generateClientId : ->
        #return ClientId.generateClientIdSeq 1

        try
            buf = crypto.randomBytes BITS/8      # crypto strong pseudo rand
            # base64 is not url safe, replace + and / to - and _
            clid = buf.toString('base64').replace(/\+/g, '-').replace(/\//g, '_')
        catch error
            clid = null

        return clid

    @generateClientIdWithSeed : (seed, clientId) ->
        crypto.createHmac('sha512', seed).update(clientId).digest("base64")


#
# push id generator and validator
# Every client registation and refresh request produces a new push id.
# These must be generated using the URL-safe base64 encoding of the SHA-1 hash
# of the string produced by concatenating the client id, a server-configured
# secret salt, and a refresh count
#
#   from hashlib import sha1
#   from base64 import urlsafe_b64encode
#
#   digest = sha1(client_id + salt + str(refresh_count)).digest()
#   print urlsafe_b64encode(digest)
#
class PushId
    sequence = 0

    # For test only. Factory to generate a client id sequentially
    @generatePushIdSeq : (clientId, refreshCount) ->
        sequence += 1
        id = sequence

        puid = clientId + '-' + id + '-' + refreshCount
        return puid

    # sha1 digest url
    @shaDigest : (data) ->
        digest = crypto.createHash('sha1').update(data).digest('base64')
        # make sure url safe
        puid = digest.replace(/\+/g, '-').replace(/\//g, '_')
        return puid

    # factory to generate a push id using sha1
    @generatePushId : (clientId, refreshCount) ->
        data = clientId + Config.getConfig('SALT') + refreshCount
        return PushId.shaDigest data

    @generatePushIdWithSalt : (salt, clientId, refreshCount) ->
        data = clientId + salt + refreshCount
        return PushId.shaDigest data

exports.ClientId = ClientId
exports.PushId = PushId

#
# unit tests of re-generate puid from client id
# I'd like to see some tests that use known values of the client id given a known random number generation seed and salt.
# I'd like to see a test that shows that different salts give different client ids (with the same random number generation seed).
# I'd like to see a test that shows that different random number generation seeds give different client ids (with the same salt).
# I'd like to see some tests that use known values of the client id and show that known (and different) push ids are generated for different refresh counts.
#
unit = ->
    diff = (testcase, clid, puid1, puid2) ->
        if puid1 is puid2
            console.log 'Match :', testcase, ' src-id ', clid, ' gen-id1 ', puid1, ' gen-id2 ', puid2
        else
            console.log 'No Match :', testcase, ' src-id ', clid, ' gen-id1 ', puid1, ' gen-id2 ', puid2

    # different salts give different client ids
    test1 = ->
        clid = 'hello-elephant'
        clid1 = ClientId.generateClientIdWithSeed 'known-seed', clid
        clid2 = ClientId.generateClientIdWithSeed 'known-seed1', clid
        diff 'different salts give diff client id', clid, clid1, clid2

    # same salt gives the same client ids
    test2 = ->
        clid = 'hello-elephant'
        clid1 = ClientId.generateClientIdWithSeed 'known-seed', clid
        clid2 = ClientId.generateClientIdWithSeed 'known-seed', clid
        diff 'same salt gives same client id', clid, clid1, clid2

    # same salt gives the same pushid
    test3 = ->
        clid = 'hello-elephant'
        puid1 = PushId.generatePushId clid, 1
        puid2 = PushId.generatePushId clid, 1
        diff 'same salt generates same push id', clid, puid1, puid2

    # different salts give different push ids
    test4 = ->
        clid = ClientId.generateClientId()
        puid1 = PushId.generatePushIdWithSalt clid, 1
        puid2 = PushId.generatePushIdWithSalt clid, 2
        diff 'diff salts generate diff push id', clid, puid1, puid2

    # use known values of the client id and show that known (and different) push ids are generated for different refresh counts.
    test5 = ->
        clid = 'hello-elephant'
        puid1 = PushId.generatePushIdWithSalt clid, 1
        puid2 = PushId.generatePushIdWithSalt clid, 2
        diff 'different push id generated from different refresh counts', clid, puid1, puid2


    test1()
    test2()
    test3()
    test4()
    test5()

#unit()
