#!/usr/bin/env coffee
#
# server main
# start both app server and spdy server
#
# to compile javascript
#   coffee -b -o lib -c src

require "coffee-script"
require "simple-errors"

# enable heap dump.
heapdump = require('heapdump')
moment = require('moment')

EventEmitter = require("events").EventEmitter
AppServer = require("./api/appserver").AppServer
SpdyServer = require("./api/spdyserver").SpdyServer
Config = require("./config/config")
PoolLayer = require("./pool/poollayer")
Blacklist = require("./persistence/blacklist").Blacklist


main = (notifyParent) ->
    options =
        notifyParent: notifyParent # set up a way for caller to know when server is ready
        app_port: Config.getConfig("APP_PORT")
        spdy_port: Config.getConfig("SPDY_PORT")
        workers: Config.getConfig("WORKERS")
        storage: Config.getConfig("STORAGE")
        pushStorage: Config.getConfig("PUSH_STORAGE")

    # create a single blacklist storage, and attach it to options
    blacklist = Blacklist.create options
    options.blacklist = blacklist
    
    PoolLayer.startServer AppServer, SpdyServer, options


process.on "SIGINT", ->
    console.log "#{moment().format()}: supervisor asks to stop, exit now !!!"
    process.exit 1


process.on 'SIGUSR2', ->
    heapdump.writeSnapshot Config.getConfig("HEAPDUMP") + Date.now() + ".heapsnapshot"
    console.log "#{moment().format()}: getting SIGUSR2 "


# tty input for background process
# intercept tty input signal and force a gc, need to enable --expose-gc flag and --trace_gc.
process.on 'SIGTTIN', ->
    console.log "#{moment().format()}: process  #{process.pid} SIGTTIN, force a gc ! "
    global?.gc?()


# sequelize will throw
process.on "uncaughtException", (err) ->
    console.log "#{moment().format()}: elephant exception : #{err}"
    console.log err.stack
    process.exit 1

module.exports = main


# let the show start !
unless process.env.NODE_ENV is "unit"
    notifyParent = new EventEmitter()
    notifyParent.on "success", (workerId) ->
        console.log "#{moment().format()}: worker #{process.pid} started successfully #{workerId}"

    main notifyParent
