#!/bin/sh

#
# run as many clients as possible
#

dtach -n dtach.1 ./runclient.sh 6000
dtach -n dtach.2 ./runclient.sh 6000
dtach -n dtach.3 ./runclient.sh 6000
dtach -n dtach.4 ./runclient.sh 6000
dtach -n dtach.5 ./runclient.sh 6000
dtach -n dtach.6 ./runclient.sh 6000
dtach -n dtach.7 ./runclient.sh 6000
dtach -n dtach.8 ./runclient.sh 6000
