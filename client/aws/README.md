# Load Testing

To perform load testing, we need to launch a set of spdy clients to simulate
massive load of concurrent connections.

Our simulated client is coded in such a way that it can spawn a number of 
threads and each thread simulates one spdy client and make spdy requests
to elephant server and maintain the persistent connections.

# AWS instance

According to my tests on my local machine, one ubuntu box can make 20k
requests at the cost around 7G memory.
Based on this data, we plan to use Amazon AMI instance type m1.large.

To generate 500k connections, we need around 20 instances.

We create one AMI image with ulimit.conf increased to 1 million.
The AMI Id is 'ami-f75cd09e'
All the instances are named after 'elephant-spdy-client-x'
All the instances are in us-east region.

After done testing, we put the instances into stop state and re-use them
for next test.


# Tools

We use boto to interact with AWS instance.
We need to distribute both the spdycli binary and the spdylay library, libspdylay.so.1
We use fabric to distribute spdyclient to each AWS instance.

For fabric, we need to use dtach to detach the client from fabric shell so that fabric
can proceed without being blocked.
Also, because we are getting AWS instance public dns name dynamically at each run, we use
with settings(host_string='instance_public_dns_name') trick.

For fabric, we need to set 
    env.reject_unknown_hosts = False
    env.disable_known_hosts = True
so ssh can operate without being disrupted.


# configuration

## tcp port range

At client side, each one connection means two socket to elephant server.
TCP port range is only 64k, so we can not generate more than 64k connections from client.
The default ip_local_port_range is from 32768 to 61000, limits us to only 32k connection.
We need to reduce the low bound of port range to start from 1024.

Change the following in /etc/sysctl.conf, or manually change it.

    sudo sysctl -w net.ipv4.ip_local_port_range = 1024 61000

    sudo sysctl -p

## stack size

The default stack size for each thread(process?) is 8m, ulimit -s.
The virtual memory required to create 30k threads will be mounted to more than 240G.
In our test, after virtual memory goes up to 260G, the entire system stop working due to can not
allocate memory.

The proper stack size for our test client is 1m. so 
    ulimit -s 1024

## pid_max

Linux by default set pid max to 32k.
    cat /proc/sys/kernel/pid_max

In our test, after reduced stack size, we ran to this issue while we still have memory.
To increase the value, 

    sudo bash -c 'echo 64000 > /proc/sys/kernel/pid_max'



# Test Command

First, activate virtual environment
    workon boto 

List exported commands
    fab -f loadEle.py -l

We have already create aws instances named elephant-spdy-client-[0-19].
All we need is to start any number of those client and launch tests.
After launching, eacah client will siege 40k connections to elephant-dev server.

    fab -f loadEle.py loadTest:2

To ssh to the instance:
     ssh -i ~/.ssh/elephant.pem ubuntu@ec2-54-234-52-92.compute-1.amazonaws.com
    or
    ./sshaws.sh ec2-54-234-52-92.compute-1.amazonaws.com


