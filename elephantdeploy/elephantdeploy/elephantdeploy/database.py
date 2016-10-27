from fabric.api import task
from gusset.output import status
from elmer.database import load_component_data, initialize_database


@task
def setup_database():
    """
    Initialize Elephant Database.
    """
    status("Initializing Elephant database")

    dbdata = load_component_data("mysql-server-conf")["database"]

    initialize_database(dbdata["name"],
                        dbdata["host"],
                        dbdata["admin"]["username"],
                        dbdata["admin"]["password"],
                        dbdata["username"],
                        dbdata["password"],
                        target_hostnames=dbdata["grant_hosts"])
