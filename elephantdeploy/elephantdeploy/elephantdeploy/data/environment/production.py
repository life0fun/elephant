""" production environment overrides. """

database = {
    "host": "elephant-web1",
}

logstash = {
    # XXX set logstash server in production
}

statsd = {
    "graphite": {
        #"server": "",  # XXX set graphite server in production
    },
    "client": {
        "deployment": "prod",
    }
}

keepalivedcore = {
    "network": {
        'vrrp_subnet': '172.16.0.0/24',
        'netmask': '255.0.0.0',
        'gateway': '10.0.0.1',
        'private_netmask': '255.255.255.0'
    },

    "data": {
        # routing for elephant-gateway1 and 2
        '69.25.109.203': {
            'virtual_router_id': 1,
            'subnet_prefix_size': 24,
            'vmapping': {
                '443': [
                    {'ip': '10.109.203.1', 'port': '443', 'weight': 5},
                    {'ip': '10.109.203.2', 'port': '443', 'weight': 5},
                ],
            }
        },

        # routing for elephant-web1
        '69.25.109.238': {
            'virtual_router_id': 2,
            'subnet_prefix_size': 24,
            'vmapping': {
                '443': [
                    {'ip': '10.109.238.1', 'port': '443', 'weight': 5},
                ],
                '8443': [
                    {'ip': '10.109.238.1', 'port': '8443', 'weight': 5},
                ],
            }
        }
    }
}

ratelimitedconf = {
    "rate_limited_ports": [443, 8443]
}
