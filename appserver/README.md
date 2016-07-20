# App Server emulator

We need a simulated application server to send push requests continously to elephant
in order to verify the correctness of functionality of our push server as well as
perform some stress push tests on elephant 

The main functionality of App server simulator is to siege batches of push requests
to elephant server continuously.

The app server is running as a nodejs app, sending requests following configured 
parameters upon start.


## Configuration

All the configuration to simulated app server is stored in a configuration file
called appserverconfig.js at the project home directory.

Upon start, app server simulator reads a local file that contains a list of 
client ids and push ids. App server will send push requests to those clients.

The client list file is configurable by the global app server configuration file.

Each line in the client list file contains client id and push id for one client.
Elephant stores all connected client ids and push ids in spdyclient database 
connected_push_id table. The mysql database server is configured in global configuration file.

We provide a util tool called genclients.py to query the database and dump all
connected clients to be used to configure app server for push test.
Following command creates clients.txt file for app server push test. 
Run this program at the mysql server machine or anywhere with host=elephant-dev.

    ./genclients.py | tee clients.txt

The alternative bash command:

 rm /tmp/clients.txt; mysql -uroot -pelephant -e "use spdyclient; select clientid, pushid from connected_push_id into outfile '/tmp/clients.txt'";

 scp root@elephant-dev:/tmp/clients.txt /opt/haijin/dev/elephant/elephant/appserver/

Due to connection dispatch, spdy client database needs to be shared across all servers. We use elephant-dev server as our database server that stores spdyclient db.


## Stochastically submit variable length push message with variable sleep intervals

Our simulated app server will push a variable size of data to each client.
The server will sleep a variable interval between continuous pushes.
The distribution of size and sleep interval should follow a Poisson distribution.

To achieve stochastic submission, we use timer to achieve intervals that pertains
stochastic characteristic.

At this moment, we only support random distribution of push size of sleep interval.

We are planning to support Poisson distribution.

## Simulate Error conditions.

1. Slow client
   We introduce random sleep on the client to simulate the slow response of client.
   This will cause push ack timeout error on the server side and we can test the
   error handling logic.

2. No exist client
   Put some invalid client ids in the client list file to test the handling of 
   invalid client id.

3. Premature disconect
   Simuate App Server will send died message to client. s

## Spdy Client emulator

In order to emulate massive connected clients, we have spdy client to pthread_create
as many clients as needed for testing. Upon client starts, it will obtain pushId 
through register API and then uses the pushId to call push API to listen to server
push messages. The command to start spdy client is

    ./spdycli -f -l -n 10 -v


## Emulation Test

First, start elephant server by running start.sh

Second, start spdy clients wiht -f flag to indicate spdy client should run
the full flow, register API and listen API.

Lastly, run the App server
    cd appserver
    node app.js

Watch the push request and ack responses.
