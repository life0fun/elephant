from os.path import join, dirname

from fabric.api import env
from confab.api import *  # noqa
from elmer.api import *  # noqa
from elmer.bootstrap import bootstrap, reboot_host  # noqa
from fabware.manage import *  # noqa

from elephantdeploy.database import setup_database  # noqa
from elephantdeploy.manage import *  # noqa


env.use_ssh_config = True

generate_tasks(join(dirname(__file__), "elephantdeploy"))
