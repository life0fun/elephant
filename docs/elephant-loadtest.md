# Elephant Scalability Test Automation

This document describes elephant scalability test automation.

## Goals

The goal of elephant scalability test should answer the following questions:

  1. performance bottlenecks for elephant APIs and services.
  2. whether elephant can deliver promised QoS under proposed usage model.
  3. the memory usage for different number of spdy clients.
  4. the metrics of spdy requests, under the load of different number of spdy clients.
  5. the metrics of push requests, under the load of different number of spdy clients.
  6. server metrics under different ping interval
  7. server metrics after long running push test
  

We shall schedule the load test daily, if possible, without interfering with other long running tests. We shall store all logs and results to a web store, and generate reports and publish them for analysis.

We shall produce consistent result from daily tests, and be alerted of any regression from the test. The scalability test shall give us capability to reproduce bug from field, as well as help us find insidious bugs that can cause performance degradation and resource leak at the earliest stage.


## Metrics

If applicable, the metrics shall include the following 
  1. server and test slave cpu load, memory info, network throughput, disk IO.
     The data can be obtained from diamond whisper db, or collected from running dstat during the test.

  2. request response time

  3. request response status

  4. elephant server request rate

  5. elephant mysql slow query analysis, if needed

  6. client persistent connection duration histogram.

  7. Push timeout metrics.

  8. requests error rates.


## Scalability Test Framework

There are some options available for distributed load test framework.

  1. Multi-Mechanize, VCI scalability team is using this framework with python test script to run load test distributed. It is python based. As we do not have python implementation of spdy client, xmm probably not a good fit here.

  2. [Nodeload] [nodeload] is a framework for load test with node. It has built-in modules to run test remotely, collect stats, monitoring tests, and reporting result. Unfortunately the lib is not actively developed or maintained.

  3. Stampede is our in house load test module.


Before we have better load test framework to run our Stampede test clients, we will improve our stampede test client with remoting, monitoring, and reporting features.


## Usage Model

The scalability requirement to elephant server is solely dependent on family locator business model. The original design requirements state that there are 2 push request per user per day and 50k connected clients at the launch. We expect those data to be change dynamically constantly to reflect real status in the field.

We need to versionalize usage model, parameterize each model, and generate test case configuration data based on usage models. This will ensure there is no disconnect between product requirements and our load tests.

The parameters for each usage model version are:

  1. total number of connected clients
  2. max, min push requests per client per day, and its deviation.
  3. push timeout threshold
  4. push requests time series distribution model to calculate peak load factor
  5. projected client disconnect and re-connect rate and distribution
  6. client ping interval


## Test Cases and Configurations.

Broadly, we need two test types, and each test type contains individual test cases.

  1. QoS satisfication test, to ensure elephant can deliver the designed performance under each usage model.

  2. Performance stress test, to find possible performance issues and performance bottlenecks under various loads.


For each test case, test configuration parameters are generated by usage model, as well as from the enumeration of some parameters when needed to pin-point performance bottlenecks.

  1. test target
  2. test api
  3. request interval
  4. test start/end time
  5. test duration, or number of pushes to achieve.

For each client, for each request, record the following

  1. total number of connections so far
  2. current test slave load
  3. request status, error information.


We want to run test with 1k clients, 10k clients, 30k clients, and 50k clients for now, nightly from cron job.


## Metrics collecting

Test metrics is covered by EL-265 and SYS-358.

In addition to the metrics discussed in SYS-358, we also need to collect heap dumps and mysql slow query analysis if needed.

when testing from ec2 where metrics reporting is not available, we can run basic linux monitor commands like dstat, iostat, etc to collect metrics and dump them together with test result.


## Test Result Store and Reporting

For each test case, we want to store all related logs and heap dumps. we also post processing logs to generate test results.

We shall store logs in a dedicated storage server for elephant. File server folders shall be named by test date, and log files shall be named by test case name plus test date. Organizing logs in the hierarchy allows parameterization of log file locations in our post process scripts. 


The hardware requirements for log server and metrics server are highly dependable on the actual load of the server and tests. Shall we share the resource or leveraging the existing cte setup are some options which could change over the time. At the moment, we would request a dedicated server for both log storage and metrics server. 


Once test is done, we pull logs from elephant and stampede and archive them.
we process stampede logs to publish test slave metrics to graphite.
We can process elephant logs to publish extra metrics that elephant doesn't already publish. like mysql slow query log. we also store elephant server heap dumps, and profiling logs.

An example from VCI scalability test can be found at 
  http://cte-monitor1/results/webflows/

Post process script shall produce test results for each test case that includes:

  1. total number of requests
  2. overal request rate of the test case
  3. avg response latency
  4. reponse latency histogram
  5. overall error rate(no response time out, etc)
  6. server load during the test time.


An example of post process script as follows:

  1. from test client log, get all the test cases that had been run.
  2. from server log, get server metrics during span of each request.
  3. some statistic processing of server metrics.
  4. generate result for each request.
  5. aggregation of request metrics for each test case, test suite.
  6. store each request result into graphite storage.


After generating test results for test cases, we shall store them into whisper store in graphite for visualize. We can use [graphitesend][graphitesend] library for publishing test results into graphite. The advantage of using graphite as storage is that we have unified metrics storage for all of our test results.


We also produce daily test summary html web page. The html can contains pictures generated using graphite render api for better data visualization. We can enrich the report with more important metrics later when needed.


## Work Flow

The main load test orchestrator script will perform the following tasks:

  0. start server on cte, clean up db and log directories.
  1. launch test slave on cte, checkout test repo.
  2. config test cases to be run, clean up.
  3. warm-up, setup persistent connecteds if needed
  4. run test
  5. test done, test runner collects logs from elephant servers and stampede test slaves, and generate server heap dumps and elephant v8 engine profile logs.
  6. test runner ship logs, and archive logs.
  7. post process generate reports and push metrics to graphite.
  8. post process generate and publish test summaries


## Test scripts

Following are test scripts needed:

  1. test setup scripts, include checking the healthy of dependency services.
  2. test configuration, generate test instance with passed in parameters.
  3. log ship, heap dump, profiling log, etc.
  4. post process generate test results for each test.
  5. populate test result to graphite whisper db.
  6. generate overall nightly test summary.



## Phasing

We need to break down the work into phases and pieces for execution.

Breakdowns are:

  1. setup log and metrics servers.
  2. test client can record the needed metrics.
  3. test client can be scheduled to run from Jenkins
  4. test client can save the logs with meaningful name.
  5. test clients and server can publish metrics, if applicable.
  6. Test runner can ship test client logs from test slave and publish to file storage.
  7. Test runner can ship server logs, heap dumps, profiling logs to file storage.
  8. post process script can pull down logs and generate test result.
  9. post process script can store needed test results to graphite storage.
  10. post process script can generate summary html and publish it.


[nodeload]: https://github.com/benschmaus/nodeload
[graphitesend]: [https://github.com/daniellawrence/graphitesend]