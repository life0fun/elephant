"""
fabric tasks for elephant management.
"""

from confab.api import iter_hosts

from fabric.api import task, sudo
from time import sleep


@task
def wait_for_elephant(max_waits=5, wait_interval=5):
    """
    Wait for elephant server to start on hosts in the environment.
    """
    def check_elephant(max_waits, wait_interval):
        for _ in range(max_waits):
            elephant_status = sudo("supervisorctl status elephant")
            if "RUNNING" in elephant_status:
                return
            sleep(wait_interval)
        else:
            raise Exception("Reached max waits while waiting for elephant to start")

    for host in iter_hosts():
        check_elephant(int(max_waits), int(wait_interval))


@task
def apt_update():
    """
    Run `apt-get update`.
    """
    sudo("apt-get update")
