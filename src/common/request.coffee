#
# request handling helpers.
#


###
# Ends the request sending back json
# @param {Response} res
# @param {Integer} status code
# @returns {Object} json object
###
exports.jsonify = (res, status, json) ->

    jsonStr = JSON.stringify json
    res.writeHead status, {
        "Content-Type": "application/json",
        "Content-Length": jsonStr.length
    }
    res.end jsonStr

###
# Statsd timing helper that records failure when
# an error exists and success otherwise.
# @param {Statsd} statsd is used to record timing.
# @param {String} name is the statsd name.
# @param {number} start time of the interval, usually from Date.now().
# @param {boolean} failure of the request. Optional, defaults to false.
# @param {number} end time of the interval. Optional, defaults to Date.now().
###
exports.recordTiming = (statsd, name, start, failure, end) ->

    # In tests we can configure the end state.
    end = end or Date.now()
    duration = end - start

    if failure
        statsd.timing "#{name}.failure", duration
    else
        statsd.timing "#{name}.success", duration
