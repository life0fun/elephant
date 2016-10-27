""" vagrant environment overrides. """

iptables = {
    "local_network": "0.0.0.0/0",
    "app": {
        "interface": "eth1",
    },
}

database = {
    "host": "elephant-vagrant",
}

logging = {
    "level": "debug",
}

statsd = {
    "client": {
        "deployment": "vagrant",
    }
}
