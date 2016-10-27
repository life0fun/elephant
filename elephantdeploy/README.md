# elephant deploy

Deploy project for elephant.

## Overview

  elephantdpeloy is an elmer based deployment project. It includes fabric tasks and
  elmer components to automate elephant deployment.

## Install

   Clone the elephantdeploy git repository. It comes with a fabfile.py that exposes all
   elephantdeploy fabric tasks.

       git clone git@git.locationlabs.com:elephantdeploy
       cd elephantdeploy
       pip install -e .

   elephantdeploy is also published in a Python distribution, which allows reuse of
   elmer components and fabric tasks:

       pip install elephantdeploy

## Usage

   Run `fab -l` to see the list of available fabric tasks.

   To deploy latest elephant 1.0.0-dev version to the 'dev' environment, for example:

       fab dev deploy:version=1.0.0-dev-SNAPSHOT

   To initialize the elephant database:

       fab <env> -H <db-host> setup_database

   The tasks require sudo access to elephant hosts.
