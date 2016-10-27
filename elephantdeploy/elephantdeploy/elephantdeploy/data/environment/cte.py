""" CTE environment overrides. """

node_flags = "--nouse-idle-notification --expose-gc --trace-gc"

database = {
    "host": "elephant-cte1",
}

logstash = {
    "tcp": {
        "host": "cte-db3",
    },
}

statsd = {
    "graphite": {
        "server": "cte-db3",
    },
    "client": {
        "deployment": "cte",
    }
}

keepalivedcore = {
    "network": {
        'vrrp_subnet': '10.101.101.0/24',
        'netmask': '255.248.0.0',
        'gateway': '172.24.0.1',
        'private_netmask': '255.255.255.0'
    },

    "data": {
        # routing for elephant-lvs-cte1 and 2
        '66.211.104.164': {
            'virtual_router_id': 1,
            'subnet_prefix_size': 25,
            'vmapping': {
                '443': [
                    {'ip': '172.26.164.1', 'port': '443', 'weight': 5},
                    {'ip': '172.26.164.2', 'port': '443', 'weight': 5}
                ],
                '8443': [
                    {'ip': '172.26.164.1', 'port': '8443', 'weight': 5},
                    {'ip': '172.26.164.2', 'port': '8443', 'weight': 5}
                ]
            }
        }
    }
}

ratelimitedconf = {
    "rate_limited_ports": [443, 8443]
}
