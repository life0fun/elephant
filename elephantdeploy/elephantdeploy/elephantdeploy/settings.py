"""
Confab settings for elephant environments.
"""

from lvsdeploy.settings import componentdefs as lvsdeploy_componentdefs
from elephantdeploy.environments import (dev,
                                         stable,
                                         cte,
                                         production,
                                         vagrant,
                                         local)

environments = [
    dev,
    stable,
    cte,
    production,
    vagrant,
    local,
]


def env_name(env_module):
    return env_module.__name__.split('.')[-1]


environmentdefs = {env_name(env): env.hosts for env in environments}


roledefs = {
    'elephant': [],
    'database': [],
    'nagios': [],
    'keepalived': [],
    'ratelimited': [],
}


# merge each environment's roledefs.
for env in environments:
    for role in roledefs:
        roledefs[role] += env.roledefs.get(role, [])


componentdefs = {
    'elephant': [
        'iptables',
        'python',
        'supervisor',
        'nodejs',
        'mysql-server',
        'mysql-server-conf',
        'elephantcore',
        'openjdk6',
        'logstash',
        'statsd',
        'diamond',
    ],

    'database': [
        'mysql-server',
        'mysql-server-conf',
    ],

    'keepalived': lvsdeploy_componentdefs['keepalived'],

    'ratelimited': lvsdeploy_componentdefs['ratelimited'],
}
