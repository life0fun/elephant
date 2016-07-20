#!/bin/sh

#
# this script should be run from fab 
# fab runclient.sh 1 -H hostname -i path/to/key -u usernameForInstance
#
# -b 0 exponential backoff, 1 random backoff with max 10 seconds.
#

cmd='./spdycli -l -v -p -n '
cmd='./spdycli -f -b 0 -l -n '
num=$1

if [ $# -eq 0 ]
then
    num=1
else
    num=$1
fi

export LD_LIBRARY_PATH=.:$LD_LIBRARY_PATH
echo $num
execmd=$cmd$num
echo $execmd
sudo bash -c 'echo 64000 > /proc/sys/kernel/pid_max'
ulimit -s 1024
s=`ulimit -s`
echo 'current stack size:' $s
$execmd
