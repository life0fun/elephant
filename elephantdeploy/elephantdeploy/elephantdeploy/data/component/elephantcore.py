""" Default configuration for the elephantcore component. """


iptables = {
    "app": {
        "interface": "eth0",
    },
}


logging = {
    "level": "info",
    "level_accounting": "info",
}

revoke_api = {
    "enabled": False,
}

node_flags = "--nouse-idle-notification"
