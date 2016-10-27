""" Elephant production environment definition file. """

elephant_hosts = [
    'elephant-web1',
]

lvs_hosts = [
    'elephant-lvs1',
    'elephant-lvs2',
]

hosts = elephant_hosts + lvs_hosts

roledefs = {
    'elephant': elephant_hosts,
    'keepalived': lvs_hosts,
    'ratelimited': lvs_hosts,
}
