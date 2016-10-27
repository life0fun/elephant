""" mysql-server-conf component configuration defaults. """

mysql = {
    'server_id': 1,
    'max_connections': 100,
    'innodb': {
        'buffer_pool_size': '256M',
        'log_file_size': '5M',
    },
}

database = {
    "name": "spdyclient",
    "host": "localhost",
    "admin": {
        "username": "root",
        "password": "root",
    },
    "username": "elephant",
    "password": "elephant",
    "grant_hosts": ["%", "localhost"],
}
