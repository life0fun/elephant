""" stable environment overrides. """

database = {
    "host": "elephant-stable",
}

logging = {
    "level": "debug",
}

logstash = {
    "tcp": {
        "host": "vci-lm-logstash1",
    },
}

statsd = {
    "graphite": {
        "server": "vci-lm-graphite1",
    },
    "client": {
        "deployment": "stable",
    }
}
