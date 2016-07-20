#!/usr/bin/env python

"""
wrap the call to spdycli to form the unit test
must be invoked from projec top level, as it refers aws/spdycli from top level.
"""

import sys
import os
import optparse
import re
import shutil
import logging
import tempfile
import distutils.sysconfig
try:
    import subprocess
except ImportError, e:
    if sys.version_info <= (2, 3):
        print 'ERROR: %s' % e
        print 'ERROR: this script requires Python 2.4 or greater; or at least the subprocess module.'
        print 'If you copy subprocess.py from a newer version of Python this script will probably work'
        sys.exit(101)
    else:
        raise

try:
    set
except NameError:
    from sets import Set as set

class Logger(object):
    @staticmethod
    def log(*k, **kw):
        #print k
        pass

def call_subprocess(cmd, show_stdout=True,
                    filter_stdout=None, cwd=None,
                    raise_on_returncode=True, extra_env=None,
                    remove_from_env=None):
    cmd_parts = []
    for part in cmd:
        if len(part) > 40:
            part = part[:30]+"..."+part[-5:]
        if ' ' in part or '\n' in part or '"' in part or "'" in part:
            part = '"%s"' % part.replace('"', '\\"')
        cmd_parts.append(part)
    cmd_desc = ' '.join(cmd_parts)
    if show_stdout:
        stdout = None
    else:
        stdout = subprocess.PIPE
    Logger.log("Running command %s" % cmd_desc)
    if extra_env or remove_from_env:
        env = os.environ.copy()
        if extra_env:
            env.update(extra_env)
        if remove_from_env:
            for varname in remove_from_env:
                env.pop(varname, None)
    else:
        env = None
    try:
        proc = subprocess.Popen(
            cmd, stderr=subprocess.STDOUT, stdin=None, stdout=stdout,
            cwd=cwd, env=env)
    except Exception, e:
        Logger.log("Error %s while executing command %s" % (e, cmd_desc))
        raise
    all_output = []
    if stdout is not None:
        stdout = proc.stdout
        while 1:
            line = stdout.readline()
            if not line:
                break
            line = line.rstrip()
            all_output.append(line)
            if filter_stdout:
                level = filter_stdout(line)
                if isinstance(level, tuple):
                    level, line = level
                Logger.log(level, line)
            else:
                Logger.log(line)
    else:
        proc.communicate()

    proc.wait()
    if proc.returncode:
        if raise_on_returncode:
            if all_output:
                Logger.log('Complete output from command %s:' % cmd_desc)
                Logger.log('\n'.join(all_output) + '\n----------------------------------------')
            raise OSError(
                "Command %s failed with error code %s"
                % (cmd_desc, proc.returncode))
        else:
            Logger.log(
                "Command %s had error code %s"
                % (cmd_desc, proc.returncode))

    # get the last line and return it
    result = all_output[-1:]
    print result

def main():
    parser = optparse.OptionParser(
        version="%prog 1.0",
        usage="%prog [OPTIONS]")

    parser.add_option(
        '-r', '--register',
        action='count',
        dest='register',
        default=0,
        help="register request")

    parser.add_option(
        '-p', '--pushlisten',
        action='count',
        dest='pushlisten',
        default=0,
        help="push listening request")

    parser.add_option(
        '-b', '--badRequest',
        action='count',
        dest='badrequest',
        default=0,
        help="bad request")

    parser.add_option(
        '-q', '--quiet',
        action='count',
        dest='quiet',
        default=0,
        help='Decrease verbosity')

    parser.add_option(
        '-a', '--unauthorized',
        action='count',
        dest='unauthorized',
        default=0,
        #metavar='PYTHON_EXE',
        help='unauthorized request (%s)' % sys.executable)

    options, args = parser.parse_args()

    # set up LD_LIBRARY_PATH
    ldpath = {}
    ldpath['LD_LIBRARY_PATH'] = '.'
    aws = 'client/aws/'

    cmd = ['./spdycli']
    cmd.append('-u')
    cmd.append('-l')
    cmd.append('-n 1')
    cmd.append('-v')

    if options.pushlisten is 1:
        cmd.append('-p')
    if options.register is 1:
        cmd.append('-r')
    if options.unauthorized is 1:
        cmd.append('-p')    # unauthorized is for push listen only
        cmd.append('-a')

    Logger.log('command: ', cmd)
    call_subprocess(cmd, show_stdout=False, cwd=aws, extra_env=ldpath)

if __name__ == '__main__':
    main()
