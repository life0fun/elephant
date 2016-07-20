#!/usr/bin/env python

"""
This module can be used to query graphite server for data.
For graphite API,
    https://graphite.readthedocs.org/en/latest/render_api.html

example of query two metrics
    curl 'http://cte-db3/render?&from=-1minute&lineMode=connected
            &target=stats.gauges.scale.ssd-db.cpu.total.user
            &target=stats.gauges.scale.ssd-db.cpu.total.system'

date format
    to convert unix epoch from/to readable time
        date -d "Apr 21 16:23:15 2013" +%s
        date +%s
        date --date @1377108463

To run
  python graphite.py metric-name start-time end-time
  time format is weird as it used _ to connect time and date. hh:mm_YYYYMMDD

  ./graphite.py -s '12:50_20130826' -m stats.gauges.scale.vci-scale-core-api1.cpu.total.user

"""

import os
import socket
import re
import json
import requests     # for http request to trigger task
import argparse
import math
import textwrap
import subprocess   # to run ngrep
from datetime import datetime
import time

# graphite server
GraphiteUrl = "http://vci-lm-graphite1/render"


# use browser network inspect tab to check target name in graphite server.
MtricsMapping = {
    'push': 'stats.timers.dev.*.elephant.app_push_req_timer.mean',
    'listen': 'stats_counts.dev.*.elephant.client_listen_reqs',
    'ping': 'stats_counts.dev.*.elephant.client_pings',
    'pushack': 'stats_counts.dev.*.elephant.client_push_acks',
    'timeout': 'stats_counts.dev.*.elephant.push_timed_out_errs'
}


class Logger(object):
    verbose = False    # cls variable

    @staticmethod
    def log(*k, **kw):
        print k

    @staticmethod
    def logV(*k, **kw):
        if Logger.verbose:
            print k


def prepend_minus_str(timestr):
    if re.search('[day|hour|minute|second]', timestr):
        return "-{}".format(timestr)
    else:
        return timestr


def epoch_to_str(timestr):
    """ convert a unix epoch to readable string """
    dt = datetime.fromtimestamp(int(timestr))
    return dt.strftime('%Y-%m-%d %H:%M:%S')


def call_subprocess(cmd, cwd=None):
    Logger.logV("Running command %s" % cmd)
    try:
        devnull = open(os.devnull, 'w')
        proc = subprocess.Popen(cmd, stderr=devnull, stdin=devnull, stdout=devnull, cwd=cwd)
        #o = proc.communicate()[0]  # communicate rets a tuple (stdout, stderr)
    except Exception, e:
        Logger.log("Executing Error %s " % e)
        raise

    return proc


def avg_datapoints(datapoints):
    """ pass in a list of datapoint with first as value, second as timestamp(sec), avg them"""
    sum = 0
    cnt = 0
    for [val, ts] in datapoints:
        if val is not None:
            sum += val
            cnt += 1
    return sum/cnt


def get_graphite_data(target='stats.stats_counts.elephant.dev.client_listen_reqs',
                      start='-2minute', end='-20second'):
    """ get rawData or png from graphite.
        curl 'http://vci-lm-graphite1/render?&from=-1minute&lineMode=connected&target=stats.gauges.scale.ssd-db.cpu.total.user&target=stats.stats_counts.elephant.dev.client_listen_reqs' > x.png
    """
    params = {
        'format': 'json',
        'rawData': 'true',
        'from': '-2minute',
        'until': '-20second',
        'target': 'stats_counts.elephant.dev.client_listen_reqs'
    }
    params['from'] = start
    params['until'] = end
    params['target'] = target
    req = requests.get(GraphiteUrl, params=params)
    print "getting metrics : ", req.url
    values = json.loads(req.text)[0]
    target = values['target']
    data = values['datapoints']
    return target, data


def get_cpu(hostname, cores, start='-2minute', end='-20second'):
    """ get cpu usage from graphite with REST request. Graphite data point
        updated every 5 seconds; value needs to be dived by cores;
    """
    result = hostname + " cpu usage percentage : "
    metrics = 'stats.gauges.scale.'+hostname+'.cpu.total.'
    for mode in ['user', 'system']:
        target = metrics+mode
        avg = avg_datapoints(get_graphite_data(target, start, end))
        result += (mode + ' avg %.2f ') % (avg/cores)
    return result


def get_task_cpu(start, end):
    hostname = socket.gethostname()
    result = get_cpu(hostname, 8, start, end)
    return result


def format_data(datapoints):
    """convert unix epoch to readable time and value """
    return ["{}\t\t{}".format(str(dp[0]), epoch_to_str(dp[1])) for dp in datapoints if dp[0] is not None]


def format_metrics_name(gauge_metric, timer_api):
    return MtricsMapping[gauge_metric]
    # if timer_api is None:
    #     return gauge_metric
    # else:
    #     return "stats.timers.vci.scale.vci-scale-*.core.*.{api}.mean".format(api=timer_api)


def main(args):
    ''' format url params based on passed in args '''
    args = vars(args)   # convert namespace object to dict

    target = format_metrics_name(args['metric'], args['api'])
    print target, args['start_time'], args['end_time']

    metric, data = get_graphite_data(target, args['start_time'], args['end_time'])
    print metric, "\n".join(format_data(data))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description=textwrap.dedent('''\
            query graphite server to get metrics data within time interval
               -m metrics name
               -t timer api name
               -s start time, can be relative to current time, -20 minute, -20 second
               -e end time, can be relative to current time, -20 minute, -20 second
            To use absolute time in format HH:MM_YYMMDD
                -s 04:00_20130821
        '''))

    ''' default send event to rabbitmq directly '''
    parser.add_argument(
        '-m', '--metric',
        action='store',
        type=str,
        default='listen',
        help="query listen or push metrics")

    parser.add_argument(
        '-t', '--api',
        action='store',
        type=str,
        #default='stats.timers.vci.scale.vci-scale-core-api1.core.HistoryService.getDailyActivityStats.mean',
        default=None,
        help="query HistoryStoreClientImpl latency metric")

    parser.add_argument(
        '-s', '--start-time',
        action='store',
        type=prepend_minus_str,
        default="60minute",
        help="start time, can use relative, 20minute")

    parser.add_argument(
        '-e', '--end-time',
        action='store',
        type=prepend_minus_str,
        default="10second",
        help="end time, can use relative, 10second")

    parser.add_argument(
        '-v', '--verbose',
        action='store_true',
        default=False,
        help="enable log verbose")

    args = parser.parse_args()
    Logger.verbose = args.verbose
    #Logger.logV(args)

    # lastly invoke main
    main(args)
