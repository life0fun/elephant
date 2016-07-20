# Elephant

Elephant is a push server with persistent socket connections to devices. 
Message is pushed to device through persistent socket connections.
The protocol used between client and server is SPDY version 3.


# Installation

First, set up a node environment following the steps on the wiki:

    http://wiki/wiki/Node/SystemSetup

If you wish to run the app locally, you currently need to install mysql:

    sudo apt-get install mysql-server

Then, get the code,
    git clone git@git:elephant.git

Now you need to install v0.10.20 of node:

    nvm install v0.10.20
    nvm use v0.10.20
    nvm alias default v0.10.20

The latest version of v0.10 is v0.10.21, but there are bugs with this version
that currently make it incompatible with our tests.

The last line isn't strictly necessary, but it will make developing easier.
Otherwise when you open a new shell you will need to explicitly run the 'nvm use
v0.10.20' command again to use the correct version of node. 


Next:

    npm install
    npm install -g coffee-script grunt-cli

Now you should be able to run the app with:

    coffee src/app.coffee

# Usage

To run scalability test, need to disable log
    export NODE_ENV=scalability
    cofee src/app.coffee

To find out how many connections,
    curl http://localhost:8443/api/application/connections

# Testing

We implement our test framework based on both mocha and vows for both tdd and bdd.
We tempt to use node-sandboxed-module for mocking later, if needed.

To test with mocha,
    grunt test

# Build Process

You can build locally with:

    grunt build

On Jenkins there is an "elephant-dev" job responsible for building the elephant
develop branch with this command so it is important not to merge code back to
develop without running the command locally to make sure that changes to not
break the build.

Related, there is also an "elephant-dev-deploy" Jenkins job which takes the code
built with the "elephant-dev" job and deploys it to elephant-dev.

# Metrics

We use metrics to capture application level metrics for further investigation.
Following is the list for default metrics. We can always add more later.

    // counters
    app_push_reqs : 'app_push_reqs'
    client_push_acks : 'client_push_acks'
    push_not_connected_errs : 'push_not_connected_errs'
    push_timed_out_errs: 'push_timed_out_errs'

    client_register_reqs : 'client_register_reqs'
    client_listen_reqs : 'client_listen_reqs'
    client_pings : 'client_pings'

    // meters
    app_push_req_meter : 'app_push_req_meter'
    client_listen_req_meter : 'client_listen_req_meter'

    // timers
    app_push_req_timer : 'app_push_req_timer'

    // histogram
    client_dur_hist : 'client_dur_hist'


To collect metrics,
    curl localhost:9091/metrics


# App server and spdy client

We have coded an App server and spdy client to emulate sparkle server pushing 
requests continously to clients.

For detailed information, please refer to README.md under appserver directory.


# Debugging and Profiling

To enable d8,
    git clone git://github.com/v8/v8.git
    make dependencies
    make native
    export PATH=$PATH:$V8_HOME/v8/out/native

    node --prof app.js 
    $V8_HOME/v8/tools/linux-tick-processor v8.log

We use node webkit agent for memory profiling. 

To activate webkit agent, send SIGUSR2 to the process.
    ps -ef | grep node | grep app.js | awk '{print $2}'

To take a heap dump, go to 
    http://c4milo.github.com/node-webkit-agent/21.0.1180.57/inspector.html?host=localhost:1337&page=0


We can also use node memwatch for memory analysis. Other options include node-inspector and node-time,
but I find those are not as good as node webkit agent.

