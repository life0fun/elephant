#
# abstract metrics layer
# -----------
#

assert  = require('assert')

Node = require('../common/root')
metrics = require('metrics')
PushMetrics = require('./pushmetrics')

#
# Abstract metrics layer to wrap API to metrics
# There are only 5 types of metrics:
#   Counter, Meter, Timer, EdsHist, UnifHist
#   the object of each type has a type prop = its lowcase string value
#
#   Counter = new metrics.Counter
#   Meter = new metrics.Meter
#   Timer = new metrics.Timer
#   EdsHist = metrics.Histogram.createExponentialDecayHistogram(5000)
#   UnifHist = metrics.Histogram.createUniformHistogram(5000)
#
#
# To collect all the metrics, curl the metrics server.
#   curl localhost:9091/metrics
#   {"":{"app_push_req":{"type":"counter","count":0}, ... }}
#
class MetricsLayer

    #logger = Logging.getLogger "metrics"

    trackedMetrics = {}  # use my own metrics

    constructor: (options) ->
        @name = options.name || 'PushMetrics'
        @port = options.metricsPort || 9091
        # create server for reporting metrics
        #@port = 8127    # report to statsd at cte-db3
        @metricsServer = new metrics.Server @port, trackedMetrics
        @report = @metricsServer.report
        @createDefaultMetrics()
        #logger.debug 'MetricsLayer : create server :', @name, @port
        return @

    @create : (options) ->
        return new MetricsLayer(options)

    toString: ->
        return 'MetricsServer :' + @name

    # define a metrics
    @define: (name, value) ->
        Object.defineProperty trackedMetrics, name, \
                              { value : value, enumerable : true}

    # get a metrics from the dict
    @get : (name) ->
        return trackedMetrics[name]

    # dump all metrics
    reportMetrics: ->
        #logger.debug "report Metrics"
        # for ns of trackedMetrics
        #     for metric of trackedMetrics[ns]
        #         logger.debug "#{metric} #{trackedMetrics[ns][metric]}"

    # create a set of default metrics
    createDefaultMetrics: ->
        @addCounter PushMetrics.app_push_req
        @addCounter PushMetrics.client_push_ack
        @addCounter PushMetrics.client_register
        @addCounter PushMetrics.client_listen
        @addCounter PushMetrics.client_connect
        @addCounter PushMetrics.client_dur
        @addCounter PushMetrics.client_ping

    # add a metric to server, each type has a getter and adder
    # key = pkgname+varname, val=type; [counter, meter, hist, timer]
    addCounter : (eventName) ->
        Node.log 'add counter : ', eventName
        counter = new metrics.Counter
        @report.addMetric eventName, counter

    getCounter : (eventName) =>
        counter =  @report.getMetric eventName
        Node.log 'get counter : ', eventName, counter.printObj()
        assert.equal counter.type, 'counter'
        return counter

    addMeter : (eventName) ->
        Node.log 'add meter : ', eventName
        meter = new metrics.Meter
        @report.addMetric eventName, meter

    getMeter : (eventName) ->
        Node.log 'get meter : ', eventName
        meter =  @report.getMetric eventName
        #assert.equal meter.type, 'meter'

    addTimer : (eventName) ->
        Node.log 'add timer : ', eventName
        timer = new metrics.Timer
        @report.addMetric eventName, timer

    getTimer : (eventName) ->
        Node.log 'get timer : ', eventName
        timer =  @report.getMetric eventName
        #assert.equal timer.type, 'timer'

    addEdsHist : (eventName) ->
        Node.log 'add edshist : ', eventName
        edshist = metrics.Histogram.createExponentialDecayHistogram(5000)
        @report.addMetric eventName, edshist

    getEdsHist : (eventName) ->
        Node.log 'get edshist : ', eventName
        edshist =  @report.getMetric eventName
        #assert.equal edshist.type, 'histogram'

    addUnifHist : (eventName) ->
        Node.log 'add unifhist : ', eventName
        unifhist = metrics.Histogram.createUniformHistogram(5000)
        @report.addMetric eventName, unifhist

    getUnifHist : (eventName) ->
        Node.log 'get unifhist : ', eventName
        unifhist =  @report.getMetric eventName
        #assert.equal unifhist.type, 'histogram'

    # incr a counter with name
    incCounter : (eventName, cnt) ->
        counter = @getCounter eventName
        if counter
            counter.inc(cnt)
            Node.log 'Metrics: incr counter :', counter.printObj()

    # decr a counter
    decCounter : (eventName, cnt) ->
        Node.log 'dec counter :', eventName
        counter = @getCounter eventName
        if counter
            counter.dec(cnt)
            Node.log 'Metrics: dec counter :', counter.printObj()

    markMeter : (eventName) ->
        Node.log 'mark a meter :', eventName
        meter = @getMeter eventName
        if meter
            meter.mark()

    updateTimer : (eventName) ->
        Node.log 'update timer:', eventName
        timer = @getTimer eventName
        if timer
            timer.update(1)

    updateEdsHist : (eventName, cnt) ->
        Node.log 'update hist:', eventName
        hist = @getEdsHist eventName
        if hist
            hist.update(cnt)

    updateUnifHist : (eventName, cnt) ->
        Node.log 'update hist:', eventName
        hist = @getUnifHist eventName
        if hist
            hist.update(cnt)

module.exports = MetricsLayer
