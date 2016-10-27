""" dev environment overrides. """

node_flags = "--nouse-idle-notification --expose-gc --trace-gc"

database = {
    "host": "elephant-dev",
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
        "deployment": "dev",
    }
}

revoke_api = {
    "enabled": True,
}
