os = require 'os'
cluster = require 'cluster'

Config = require('../config/config')
helper = require('../common/helper')
Logging = require('../common/logging')


###
# Worker pool abstraction on top of node.js cluster.
# http://nodejs.org/docs/latest/api/cluster.html
###
class PoolLayer
    logger = Logging.getLogger "worker-pool"

    # default to 1, ref to class private directly.
    workers = 1

    # ip address of the host
    serverIp = undefined

    # master server is the server master should run. could not null.
    # worker server is the server each worker should run
    masterServer = undefined
    workerServer = undefined

    # Unit test, can not do cluster.fork, only one server !
    # cluster.fork just create another shell and execute the node app.js again.
    # this will cause vows testrunner to repeat. Bad
    # for unit test mode, do not fork.
    unitMode = process.env.NODE_ENV is 'unit'

    @create: (masterServerFunc, workerServerFunc, options) ->
        logger.debug "PoolLayer created", options: options
        return new PoolLayer(masterServerFunc, workerServerFunc, options)

    ###
    # Pool API layer must be lib, all static funcs.
    # @param masterServerFunc - server instance master should run.
    # @param workerServerFunc - sserver instance each worker should run.
    # @param options - common server options.
    ###
    @startServer: (masterServerFunc, workerServerFunc, options) ->

        # unit mode, do not fork, return now.
        if unitMode
            serverIp = "127.0.0.1" # unit test always to localhost
            options.serverId = @getServerAddress()
            masterServer = masterServerFunc.createServer(options)
            workerServer = workerServerFunc.createServer(options)
            return

        # first, get the ip address
        helper.getLocalhostIp (ip) =>
            serverIp = ip or '127.0.0.1'
            logger.debug "start server at #{serverIp}"

            # monkey patch add server ip addr
            options.serverId = @getServerAddress()
            numWorkers = options.workers or os.cpus().length

            # then proceed after obtaining ip address.
            if cluster.isMaster
                logger.info '>>>>> starting app server on master <<<<<'
                masterServer = masterServerFunc.createServer(options)
                @configureMaster()
                @fork workerName for workerName in [1..numWorkers]
            else
                logger.info '>>>> starting SPDY server <<<',
                    workerId: cluster.worker.id
                    workerName: @getWorkerName()
                workerServer = workerServerFunc.createServer(options)
                @configureWorker(workerServer)

    ###
    # create a new worker process with the given worker name.
    ###
    @fork: (workerName) ->
        # worker name is passed to the worker through its environment variables
        worker = cluster.fork WORKER_NAME: workerName
        # attach the name to the worker instance for later use
        worker.name = workerName

    ###
    # configure master process.
    ###
    @configureMaster: ->
        cluster.on 'fork', (worker) =>
            logger.info "worker forked",
                workerId: worker.id
        
            # listen for worker messages
            worker.on 'message', (msg) ->
                masterServer.handleWorkerMessage worker.id, msg

        cluster.on 'online', (worker) ->
            logger.info "worker online", workerId: worker.id

        cluster.on 'listening', (worker, address) ->
            logger.info "worker listening",
                workerId: worker.id
                address: address
        
        cluster.on 'exit', (worker, code, signal) =>
            logger.error "worker exited",
                workerId: worker.id
                code: code
                signal: signal

            @dumpWorkerInfo()

            # fork using the dead worker name
            @fork worker.name

    ###
    # configure worker process.
    ###
    @configureWorker: (workerServer) ->
        cluster.worker.on 'message', (msg) ->
            logger.debug 'worker got message from master',
                workerId: cluster.worker.id
                message: JSON.stringify msg

            workerServer.handleMasterMessage msg  # just relay msg obj

    # get all worker info
    @getServerInfo: ->
        if cluster.isMaster
            @dumpWorkerInfo()

    # get pool process id
    @getServerPid: ->
        if unitMode
            return process.pid

        if not cluster.isMaster
            return cluster.worker.process.pid

    ###
    # get server address as ip:port string.
    ###
    @getServerAddress: ->
        "#{serverIp}:#{Config.getConfig('APP_PORT')}"

    ###
    # parse server IP and port from server address string.
    ###
    @parseServerAddress: (address) ->
        address.split ':'

    @getWorkerId: ->
        if unitMode
            return 1    # always workerId 1
        if not cluster.isMaster
            return cluster.worker.id

    @getWorkerName: ->
        process.env.WORKER_NAME

    @toString: ->
        worker for id, worker of cluster.workers

    @dumpWorkerInfo: ->
        # log raw format, otherwise, got [object object] in the log.
        logger.debug @toString()

    ###
    # semd a message from worker to master.
    ###
    @sendMsgToMaster: (msgobj) ->
        if unitMode
            masterServer.handleWorkerMessage 1, msgobj
        else
            process.send msgobj

    ###
    # send message from master to worker.
    ###
    @sendMsgToWorker: (workerId, msgobj, cb) ->
        logger.silly "master sending message to worker",
            workerId: workerId
            message: JSON.stringify msgobj

        if unitMode
            workerServer.handleMasterMessage msgobj
        else if workerId of cluster.workers
            cluster.workers[workerId].send msgobj
        else
            logger.error "failed to send msg to worker as worker died", workerId: workerId
            @dumpWorkerInfo()
            err = Error.create "worker does not exist"

        cb? err

    ###
    # broadcast message from master to all workers.
    ###
    @bcastMsgToAllWorkers: (msgobj) ->
        if cluster.isMaster
            worker.send msgobj for id, worker of cluster.workers


module.exports = PoolLayer
