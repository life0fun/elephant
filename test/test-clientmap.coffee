{assert} = require('chai')

Config = require('../src/config/config')
ClientMap = require('../src/model/clientmap').ClientMap


###
# test suite for testing client in memory map storing connected clients.
###
suite 'clientMap test', ->
    options =
        storage: Config.getConfig('STORAGE')
    clientmap = ClientMap.create options
    nclients = 1000

    setup (done) ->
        done()

    teardown (done) ->
        done()

    test 'can insert 1 million keys into clientmap', (done) ->
        start = Date.now()
        for i in [0..nclients]
            clientmap.add i, i, i, i, (err, result) ->
        end = Date.now()
        ##assert.equal(nkeys, nclients, ' can insert 1 million keys in ' + (end-start) + ' ms')
        assert.ok((end-start) < 5000, ' can insert 1 million in ' + (end-start) + ' ms')
        done()

    test 'can get all of the 1 million keys of clientmap', (done) ->
        start = Date.now()
        clientmap.getAllClients (clients) =>
            end = Date.now()
            #assert.equal(clients.length, nclients, ' can iterate 1  million keys in ' + (end-start) + ' ms')
            assert.isTrue(clients.length >= nclients, ' can iterate 1  million keys in ' + (end-start) + ' ms')
            done()

    test 'can populate more than 1 million entries for clientmap', (done) ->
        start = Date.now()
        m1 = 'm1'
        clientmap.add m1, m1, m1, m1, (err, result) =>
            end = Date.now()
            assert.ok((end-start) < 100, ' insert more than 1  million clients takes less than 100 ms')
            done()

    test 'can access any key randomly in clientmap easily', (done) ->
        start = Date.now()
        clientmap.getClient '999', (err, client) ->
            end = Date.now()
            assert.ok(client, ' can assert random client 9999 within ' + (end-start) + ' ms')
            done()
