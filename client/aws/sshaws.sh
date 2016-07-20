#!/bin/bash

key=$HOME/.ssh/elephant.pem
sshcmd='ssh -i '
user=' ubuntu@'
cmd=$sshcmd$key$user$1
echo $cmd
$cmd
