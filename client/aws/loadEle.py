#!/usr/bin/env python

import sys
import os
import time

from boto.ec2.connection import EC2Connection
from boto.ec2.connection import EC2ResponseError
import boto.ec2

''' fabric related imports '''
from fabric.api import (run, env, settings, task,
                        hosts, local, parallel, put,
                        get, cd, lcd, sudo)
import socket
import paramiko

os.environ['AWS_ACCESS_KEY_ID'] = 'AKIAIUMPS6J7UJ46DF4Q'
os.environ['AWS_SECRET_ACCESS_KEY'] = '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'

''' for now, host is elephant, for anything local, use local()'''
env.host = 'elephant-dev.colorcloud.com'
env.user = 'ubuntu'
env.key_filename = '/ext/home/haijin.yan/.ssh/elephant.pem'
env.reject_unknown_hosts = False
env.disable_known_hosts = True


# the ami id from aws ami finder
AMI = 'ami-013f9768'
# the ami id I created with increase ulimit.conf
AMI='ami-f75cd09e'
awsconn = None
reservation = None
instances=[]
instanceNames=[]

def addEnvHosts(host):
    env['hosts'].append(host)

def showEnvHosts():
    for host in env['hosts']:
        print 'env host: ', host

def stopInstance():
    if awsconn is not None:
        awsconn.stop_instances(instance_ids=instances)

def termInstance():
    if awsconn is not None:
        awsconn.terminate_instances(instance_ids=instances)

def connectToAws():
    print 'connecting to AWS now'
    #conn = EC2Connection('<aws access key>', '<aws secret key>')
    global awsconn   # if you modify global var, declare global var
    #awsconn = EC2Connection('AKIAIUMPS6J7UJ46DF4Q', 'cuy7DDNIb20onRvHxUbuReHNL2XyptdXrUnkqFqq')
    awsconn = EC2Connection()
    print awsconn

    #runClient('localhost')
    #runClient('root@elephant-dev.colorcloud.com')

@task
def getRunningInstances(numclients):
    ''' get current running aws elephant instances with name elephant-xxx
    '''
    if awsconn is None:
        return

    instances = [i for r in awsconn.get_all_instances() for i in r.instances]
    instances = filter(lambda inst : inst.tags.has_key('Name'), instances)
    eleclients = filter(lambda inst: "elephant" in inst.tags["Name"], instances)
    print eleclients

    ''' you can only get instance public dns name when instance is running.
       when instance is stopped, there is now public_dns_name
    '''
    i = 0
    for instance in eleclients:
        if instance.public_dns_name:
            global instanceNames
            instanceNames.append(instance.public_dns_name)
            i += 1
            if i >= numclients:
                return


#@task
def startInstances(numclients):
    ''' start the pre-created aws instances with name elephant, n instances.
    '''
    if awsconn is None:
        return

    instances = [i for r in awsconn.get_all_instances() for i in r.instances]
    instances = filter(lambda inst : inst.tags.has_key('Name'), instances)
    eleclients = filter(lambda inst: "elephant" in inst.tags["Name"], instances)
    print eleclients

    numclients = int(numclients)

    i = 0
    # now start each instance
    for instance in eleclients:
        print 'Starting elephant instance ', instance
        try:
            instance.start()
        except EC2ResponseError as e:
            print 'ec2 instance error', e
            continue

        status = instance.update()
        while status == 'pending':
		    time.sleep(10)
		    status = instance.update()
		    print 'status : ', status

        if status == 'running':
            print('running instance "' + instance.id + '" accessible at ' + instance.public_dns_name)
            global instanceNames
            instanceNames.append(instance.public_dns_name)
            i += 1
            print 'running instances: ', i, ' limit: ', numclients
            if i >= numclients:  # only run this many clients
                print ' reaching max clients :', numclients
                return
        else:
		    print('Wrong Instance status: ' + status)

def runInstances(numclients):
    ''' running all the instance and get instance public dns name once up '''
    ''' I have already created 20 clients, no need to use this function any more '''
    if not awsconn:
        print 'Please connect to AWS first !'
        return

    numclients = int(numclients)
    print 'running instance : ', numclients
    return   # permanently never create instances.

    # launch aws instances
    reservation = awsconn.run_instances(AMI, instance_type='m1.large',
                                                             key_name='elephant',
                                                             min_count=numclients, max_count=numclients)

    # save the instances list of this run reservation
    global instances
    instances = reservation.instances
    print 'starting instances: ', instances, ' with max_count ', numclients

    for i in xrange(0, numclients):
        instance = instances[i]
        # tag fixed instance name.
        instname = 'elephant-spdy-client-'+str(i)
        instance.add_tag('Name', instname)
        print 'tagging instance with name : ', i, instname
        status = instance.update()

        while status == 'pending':
		    time.sleep(10)
		    status = instance.update()
		    print 'status : ', status

        if status == 'running':
            print('New instance "' + instance.id + '" accessible at ' + instance.public_dns_name)
            global instanceNames
            instanceNames.append(instance.public_dns_name)
        else:
		    print('Wrong Instance status: ' + status)

    # wait for 10 seconds before final return
    time.sleep(30)
    return

@task
def runClient(awshost, numconns):
    '''  deploy to each aws instance and run client inside each aws instance.
    '''
    with settings(host_string=awshost, warn_only=True):
        print 'running clients at instance: ', awshost
        run('mkdir -p ~/opt/aws')
        with cd('~/opt/aws'):
            run('pkill spdycli')
            put('./*', '~/opt/aws/')
            # increase tcp mem and port range
            sudo('cp sysctl.conf /etc/sysctl.conf')
            sudo('sysctl -p')
            sudo('ulimit -s 1024')
            #run('sudo apt-get install dtach')
            #run('sudo cp limits.conf /etc/security/')
            run('chmod 777 spdycli')
            run('chmod 777 runclient.sh')
            cmd1 = 'dtach -n dtach.X1 ./runclient.sh ' + str(numconns)
            cmd2 = 'dtach -n dtach.X2 ./runclient.sh ' + str(numconns)
            #run('nohup ./runclient.sh 10 &> /dev/null &', pty=False)   # hangs fabric, issue #395
            #run('screen ./runclient.sh 10 >& log.txt &')
            #time.sleep(10)
            run('chmod 777 runbatch.sh')
            #run('./runbatch.sh')
            
def runOneClient(numconns):
    client = 'ec2-50-17-5-9.compute-1.amazonaws.com'
    runClient(client, numconns)

def loadAllClient(numconns):
    for client in instanceNames:
        print ' ssh to instance to run client: ', client
        runClient(client, numconns)   # let's do 40k per client

@task
def loadTest(numclients):
    ''' start load test with n clients, connect to aws'''
    connectToAws()
    print 'Starting load test with num clients: ', numclients
    #runInstances(numclients)
    #getRunningInstances(numclients)

    # we already pre-defined a set of instance(20), start n of them
    #startInstances(numclients)
    #loadAllClient(25000)

    # one spdycli can only run up to 32k pthread, run multiple clients.
    runOneClient(6000)
