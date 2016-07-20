#!/usr/bin/env coffee

#
# This test suit contains only mysql sequelize ORM related test cases.
#

childProcess = require('child_process')
EventEmitter = require('events').EventEmitter

assert = require('chai').assert
expect = require('chai').expect
should = require('chai').should()
moment = require('moment')

Config = require('../src/config/config')
Helper = require('../src/common/helper')

#
# testing Sequelize ORM lib with push request
#
suite "push request sequelize test", ->

    PushRequestStorage = require('../src/persistence/mysqlpushrequest')

    options =
        memory: true
    storage = PushRequestStorage.create options

    pushIndex = 0
    pushRequest =
        'requestId': "requestId-1"
        'clientId': "clientId-1"
        'pushId': "pushId-1"
        'serverId': "serverId-1"
        'workerId': "workerId-1"

    setup (done) ->
        done()

    teardown (done) ->
        # delete all records in db after test done
        storage.purge done

    test 'can insert push request to storage', (done) ->
        storage.addPushRequest pushRequest, (err, savedPushRequest) ->
            if err then return done(err)
            pushIndex = savedPushRequest.pushIndex
            assert.notEqual pushIndex, 0
            assert.equal savedPushRequest.requestId, pushRequest.requestId
            done()

    test 'can get push request from storage', (done) ->
        pushRequest.requestId = "requestId-getTest"
        # first, insert push request, get push index
        storage.addPushRequest pushRequest, (err, savedPushRequest) ->
            if err then return done(error)
            assert.notEqual 0, savedPushRequest.pushIndex
            assert.equal savedPushRequest.requestId, pushRequest.requestId

            # now get the previously inserted data
            storage.getPushRequestByIndex savedPushRequest.pushIndex, (err, getPushRequest) ->
                if err then return done(err)
                assert.equal getPushRequest.requestId, pushRequest.requestId
                assert.equal getPushRequest.pushId, pushRequest.pushId
                done()

    test 'can insert push request with encryption to storage', (done) ->
        pushRequest.requestId = "requestId-insertCallback"
        pushRequest.callbackUrl = "example.com"
        pushRequest.callbackUsername = "default"
        pushRequest.callbackPassword = "secret"

        storage.addPushRequest pushRequest, (err, savedPushRequest) ->
            if err then return done(err)
            assert.equal savedPushRequest.requestId, pushRequest.requestId
            assert.equal savedPushRequest.callbackUsername, pushRequest.callbackUsername
            assert.equal Helper.aesDecrypt(savedPushRequest.callbackPassword),
                         pushRequest.callbackPassword
            done()

    test 'can get push request by description to storage', (done) ->
        pushRequest.requestId = "requestId-getCallback"
        pushRequest.callbackUrl = "example.com"
        pushRequest.callbackUsername = "default-get"
        pushRequest.callbackPassword = "secret-get"

        # first insert record, then verify get
        storage.addPushRequest pushRequest, (err, savedPushRequest) ->
            if err then return done(err)
            storage.getPushRequestByIndex savedPushRequest.pushIndex, (err, getPushRequest) ->
                if err then return done(err)
                assert.equal getPushRequest.requestId, pushRequest.requestId
                assert.equal getPushRequest.callbackUsername, pushRequest.callbackUsername
                assert.equal Helper.aesDecrypt(getPushRequest.callbackPassword),
                             pushRequest.callbackPassword
                done()


#
# blacklist orm module test
#
suite "blacklist test", ->
    BlacklistStorage = require('../src/persistence/mysqlblacklist')

    options =
        memory: true
    storage = BlacklistStorage.create options


    setup (done) ->
        storage.deleteAllRevokedClientId ->
            storage.deleteAllRevokedPushId ->
                storage.deleteAllRefreshCount ->
                    done()


    teardown (done) ->
        done()

    test 'can revoke a client id', (done) ->
        clientId = "revoked-client-1"
        storage.revokeClientId clientId, "test", (err, result) ->
            if err then return done(err)
            assert.equal result.clientid, clientId
            storage.getRevokedClientId clientId, (err, revoked) ->
                if err then return done(err)
                assert.equal revoked.clientid, clientId
                done()

    test 'can revoke a push id', (done) ->
        clientId = "revoked-client-2"
        pushId = "revoked-push-2"
        storage.revokePushId pushId, clientId, "test", (err, result) ->
            if err then return done(err)
            assert.equal result.clientid, clientId
            assert.equal result.pushid, pushId
            storage.getRevokedPushId pushId, (err, revoked) ->
                if err then return done(err)
                assert.equal revoked.pushid, pushId
                done()


    test 'can increase a refresh count', (done) ->
    
        clientId = "revoked-client-3"

        storage.incrementRefreshCount clientId, (err, result) ->

            if err then return done(err)
            assert.equal result.clientid, clientId
            assert.equal result.count, 1
    
            storage.incrementRefreshCount clientId, (err, result) ->

                if err then return done(err)
        
                # now get back the just inc record
                storage.getRefreshCount clientId, (err, count) ->

                    if err then return done(err)
                    assert.equal count, 2
                    done()


#
# client model orm module test
#
suite "client model ORM test", ->
    MysqlClientMap = require('../src/persistence/mysqlclientmap')

    storage = MysqlClientMap.create()

    setup (done) ->
        storage.purge (err, success) ->
            done()

    teardown (done) ->
        done()


    test 'can add a new connected client', (done) ->
        pushId = "connected-push-1"
        clientId = "connected-client-1"
        serverId = "locahost:443"
        workerId = 1

        storage.add pushId, clientId, serverId, workerId, (err, result) ->
            assert.equal result.pushid, pushId
            assert.equal result.clientid, clientId
            assert.equal result.hostname, serverId
            assert.equal result.workerid, workerId
            done()


    test 'can get newly inserted client by pushId', (done) ->
        pushId = "connected-push-2"
        clientId = "connected-client-2"
        serverId = "locahost:443"
        workerId = 2
        timestamp = moment().unix()

        storage.add pushId, clientId, serverId, workerId, (err, result) ->
            storage.getClient pushId, (err, client) ->
                assert.equal client.pushid, pushId
                assert.equal client.clientid, clientId
                assert.equal client.hostname, serverId
                assert.equal client.workerid, workerId
                done()


    test 'can remove a connected client by pushId', (done) ->
        pushId = "connected-push-3"
        clientId = "connected-client-3"
        serverId = "locahost:443"
        workerId = 3

        storage.add pushId, clientId, serverId, workerId, (err, result) ->
            storage.remove pushId, (err, removed) ->
                storage.getClient pushId, (err, client) ->
                    assert.isNull client
                    done()

    test 'no side effect when removing a connected client by pushId many times', (done) ->
        pushId = "connected-push-3"
        clientId = "connected-client-3"
        serverId = "locahost:443"
        workerId = 3

        storage.add pushId, clientId, serverId, workerId, (err, result) ->
            storage.remove pushId, (err, removed) ->
                storage.getClient pushId, (err, client) ->
                    assert.isNull client
                    # remove again, non exist pushId
                    storage.remove pushId, (err, removed) ->
                        assert.isNull err
                        storage.getClient pushId, (err, client) ->
                            assert.isNull client
                            done()


    test 'can remove a connected client by clientId', (done) ->
        pushId = "connected-push-4"
        clientId = "connected-client-4"
        serverId = "locahost:443"
        workerId = 4

        storage.add pushId, clientId, serverId, workerId, (err, result) ->
            storage.removeByClientId clientId, (err, pushId) ->
                storage.getClient pushId, (err, client) ->
                    assert.isNull client
                    done()


    test 'can update a connected client', (done) ->
        pushId = "connected-push-5"
        clientId = "connected-client-5"
        serverId = "locahost:443"
        workerId = 5

        valueMap =
            clientid: "updated-client"

        storage.add pushId, clientId, serverId, workerId, (err, result) ->
            storage.update pushId, valueMap, (err, result) ->
                storage.getClient pushId, (err, newClient) ->
                    assert.equal newClient.clientid, valueMap.clientid
                    done()


    test 'can get connected client numbers', (done) ->
        index = 1

        storage.add index, index, index, index, (err, result) ->
            index += 1
            storage.add index, index, index, index, (err, result) ->
                index += 1
                storage.add index, index, index, index, (err, result) ->
                    storage.getNumClients (count) ->
                        assert.equal count, index
                        done()

    
    test 'can replace into an existing connected client', (done) ->
        pushId = "connected-push-1"
        clientId = "connected-client-1"
        serverId = "locahost:443"
        workerId = 1

        updatedClientId = "updated-connected-client-1"
        updatedServerId = "updated-locahost:443"
        updatedWorkerId = 2

        storage.add pushId, clientId, serverId, workerId, (err, result) ->
            assert.isNull err, "err shall be null"
            assert.equal result.pushid, pushId
            assert.equal result.clientid, clientId
            assert.equal result.hostname, serverId
            assert.equal result.workerid, workerId

            # now add again, should update. this line is too long, I know.
            storage.add pushId, updatedClientId, updatedServerId, updatedWorkerId, (err, result) ->
                assert.isNull err, "err shall be null"
                assert.equal result.pushid, pushId
                assert.equal result.clientid, updatedClientId
                assert.equal result.hostname, updatedServerId
                assert.equal result.workerid, updatedWorkerId
                done()
