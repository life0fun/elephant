Elephant Performance Testing with JMeter 
========================================

Install JMeter and jmeter-ec2
-----------------------------

* `JMeter <http://jmeter.apahce.org>`_

  On ubuntu this is as simple as ``sudo apt get install jmeter``

* `jmeter-ec2 <https://github.com/oliverlloyd/jmeter-ec2>`_

  This just requires cloning the repo from git.

* Configure env variables (copied from the jmeter-ec2 documentation at
  https://github.com/oliverlloyd/jmeter-ec2):
  edit or create ``~/.bashrc`` to have the following env vars set::

          export EC2_HOME=~/Downloads/ec2-api-tools-1.6.x.x
          export PATH=$PATH:$EC2_HOME/bin
          export JAVA_HOME=/usr/lib/jvm/java-6-openjdk-amd64/
          export AWS_ACCESS_KEY=AKIAJX72IG42MNUHUZZQ
          export AWS_SECRET_KEY=ITFFFDnq0LFm5wzY8OCz+3M1IMAj+7xTD87UZMPg
          export EC2_URL=https://ec2.us-west-1.amazonaws.com

``EC2_HOME`` should point to your installation of ec2-api-tools. Note that
ubuntu has an ec2-api-tools package, but it should not be used because it is out
of date and will not work properly with jmeter-ec2.


Configure jmeter-ec2
--------------------

To authenticate to amazon aws, you will need a ``jmeter.pem`` file. Currently the
way to obtain this key is to get it from someone else (i.e. asked someone who
has worked on a project which used amazon ec2). Eventually, these keys
will be available through a shared password/credential storage solution. 

Next modify the jmeter-ec2.properties file included in the
jmeter-ec2/elephant directory of the elephant repo to update the following
variables for your environment: 

``LOCAL_HOME`` to point to where you cloned the
               jmeter-ec2 repo
``PEM_PATH``   to point to where you placed your jmeter.pem file.

Next navigate to the directory where you cloned the jmeter-ec2 repo. Create an
``elephant`` directory, next create ``elephant/jmx``, ``elephant/plugins``,
``elephant/results`` directories. Copy the .jmx file from the elephant repo to
the ``jmeter-ec2/elephant/jmx`` directory and the ``JMeterPlugins.jar`` file into
``elephant/plugins``. To get the ``JMeterPlugins.jar``, notice the
``example-project.zip`` package, in the jmeter-ec2 directory, unzip it and
``JMeterPlugins.jar`` will be in the plugins directory of the extracted sample
project. 

Run the Tests
-------------

Now you should be ready to run the tests. Navigate to the directoy where you
cloned the jmeter-ec2 repo and run the jmeter-ec2.sh script. You could try
running the tests with one client as follows::

          project="elephant" count="1" ./jmeter-ec2.sh

You can also specify::

          terminate="FALSE"

with this set, jmeter-ec2 will not terminate the EC2 test slaves
when the test ends, so you can reuse those slaves for a next
test run, reducing the test initialization time. If you use
this option to reuse test slaves make sure to update the
``REMOTE_HOSTS`` variable in ``jmeter-ec2.properties`` with
the list of slave hosts.

