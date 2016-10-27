""" Elephant capacity test environment (CTE) definition file. """

elephant_hosts = [
    'elephant-cte1',
    #'elephant-cte2',
]

lvs_hosts = [
    'elephant-lvs-cte1',
    'elephant-lvs-cte2',
]

hosts = elephant_hosts + lvs_hosts

roledefs = {
    'elephant': elephant_hosts,
    'keepalived': lvs_hosts,
    'ratelimited': lvs_hosts,
}
