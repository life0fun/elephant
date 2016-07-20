#!/usr/bin/env coffee

#
# App server to simulate sparkle app server to send push message to clients
#
net = require 'net'
util = require 'util'
url = require 'url'
http = require 'http'
fs = require 'fs'
path = require 'path'
qs = require 'querystring'

Node = require('../common/root')

Router = require('../router/router').Router
{ClientMap, Client} = require('../model/clientmap')
RestClient = require('./restclient').RestClient
MetricsLayer = require('../metrics/metricslayer')
PushMetrics = require('../metrics/pushmetrics')
{PushRequestManager} = require('../model/pushrequest')
Stochastic = require('./stochastic').Stochastic
Config = require('../appserverconfig.js')

# global settings to increase agent pool
require('http').globalAgent.maxSockets = 1000000

class AppServer
    constructor : (@options) ->
        @httpServer = http.createServer @onRequest
        @httpServer.listen Config.HTTP_PORT

        @clientmap = ClientMap.create({})
        @populateClients(Config.CLIENT_FILE)

        # push request manager stores all pending pushes
        @pushRequestManager = PushRequestManager.create({})

        # create the router
        @router = Router.create(this)
        @bindRouteHandler()

         # rest client interact with elephant app server
        @rest = RestClient.create('ua-sparkle')

        @pushVer = @options.pushVer
        @pushUrl = Config.PUSH_URL + @pushVer + '/'

        @pushInterval = undefined

        # now start to push to all client
        @pushToAllClients()

        Node.log 'Sparkle server started ! at ', Config.HTTP_PORT

    @create : (options) ->
        Node.log "creating app server"
        return new AppServer options

    # callback handler, fat binding.
    onRequest : (req, res) =>
        @router.route(req, res)

    # bind all router handlers
    # url must not end with / in order to match
    bindRouteHandler : ->
        @router.handleGet '/start', @startTest.bind(this)
        @router.handleGet '/stop', @stopTest.bind(this)

    # start periodical push to client
    startTest : (req, res) =>
        if @pushInterval
            clearInterval @pushInterval
        @pushInterval = setInterval @pushToAllClients, Config.PUSHALL_INTERVAL
        Node.log 'startTest : periodical push test started !!!'
        res.end('periodical push test started !!!')

    stopTest : (req, res) =>
        clearInterval @pushInterval
        Node.log 'stopTest : periodical push test stopped !!!'
        res.end('periodical push test stopped !!!')

    # perform one push to a client.
    # we set random timeout after each push so to perform continuous pushes.
    pushOneClient : (clientId, pushId, headers, data) ->
        sleep = Stochastic.getNextSleepInterval()
        tmid = undefined
        tm = =>
            tmid = undefined    # reset timer id inside timeout
            url = @pushUrl + pushId
            Node.log 'App Pushing >>>  ', url, pushId, headers
            # server res.writeHeader, then res.end()
            # we get two calls here, handle carefully.
            @rest.post url, headers, data, (err, result) =>
                if err
                    Node.logFatal 'client does not exist !', pushId, err
                    return
                else
                    Node.log 'App Pushing result :', result, err
                    if result isnt 404 and result isnt 410
                        if tmid   # already timer pending, do not set again
                            return

                        next = Stochastic.getNextSleepInterval()
                        Node.log 'sleeping ', next*1000, ' before one push to ', pushId
                        tmid = setTimeout tm, next*1000   # set new timer id

        Node.log 'sleeping ', sleep*1000, ' before one push to ', pushId
        setTimeout tm, sleep*1000


    pushHeader: (pushVer, clientId, pushId) ->
        auth = new Buffer('default:secret').toString('base64')
        headers =
            'authorization': 'Basic '+auth

        if pushVer is 'v1'
            headers['content-type'] = 'text/plain'
        else
            headers['content-type'] = 'application/json'
            headers['accept'] = 'application/json'

        return headers

    pushData: (clientId, pushId) ->
        msg =
            "message": "hello #{pushId}"
            # "callback":
            #     "url": "https://example-wrong.com"
            #     "username": "user"
            #     "password": "password"

        return JSON.stringify msg


    # populate clients from client.txt, first column is clientId and second is pushId.
    populateClients: (filename) ->
        f = path.resolve filename
        clients = fs.readFileSync(f).toString().split('\n')
        for c in clients
            if not c
                continue
            Node.log 'reading out:', c
            clpuid = c.split(/\s+/)
            # first column is clientId and second column is pushId
            @addToClientMap clpuid[0], clpuid[1], 'u-server', 'u-worker'

        #@clientmap.dump()

    # add a client, serverId and worker Id is provided.
    addToClientMap : (clientId, pushId, serverId, workerId) ->
        Node.log 'addToClientMap clientId ', clientId, ' pushId ', pushId
        cli = @clientmap.insertClientIntoMap clientId, pushId, \
                                             serverId, workerId
        return cli

    # periodical callback to execute push test
    pushToAllClients : =>
        for c in @clientmap.getAllClients()
            Node.log 'creating one push closure and start continuously pushing to one client: ', JSON.stringify c
            hd = @pushHeader @pushVer, c.clientId, c.pushId
            data = @pushData c.clientId, c.pushId
            @pushOneClient c.clientId, c.pushId, hd, data

exports.AppServer = AppServer

#
# unit
#
#main()