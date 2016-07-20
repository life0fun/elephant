#!/usr/bin/env python

"""
  This program talks to mysql spdyclient db connected_push_id table and
  exports all the connected client's client id and push id
  to be used by app server simulator to push.

  run this code locally to extract connected_push_id from remote host.
  by providing host=elephant-dev, you can extract db remotely.
  Alternative is:
     rm /tmp/clients.txt; mysql -uroot -pelephant -e "use spdyclient;select * from connected_push_id into outfile '/tmp/clients.txt'";

  Usage:  ./genclients.py
"""

import MySQLdb
import sys
import os
import optparse
import re

class SpdyDb:
    def __init__(self, user='root', passwd='elephant', dbname='spdyclient'):
        self.host = 'elephant-dev.colorcloud.com'
        self.passwd = passwd
        self.dbname = dbname
        self.cursor = None
        self.db = MySQLdb.connect(host=self.host, user='root', passwd=self.passwd, db=self.dbname)
        #print 'SpdyDb: db connected. ', self.dbname

    def query(self, sql):
        self.cursor = self.db.cursor()
        self.cursor.execute(sql)
        r = self.cursor.fetchall()

        for clid, puid in r:
            print clid, puid


    ''' hard code to generate one client id used for test only '''
    def genOneClient(self, prefix, name, id, workerId):
        cli = prefix + name + '-' + str(id) + '-' + str(workerId)
        print cli


    def genClients(self, name):
        for workerId in xrange(1,5):
            for i in xrange(0, 30):
                self.genOneClient('clid-', 'a', name, i, workerId)   # assume all on worker 1

if __name__ == '__main__':
    spdydb = SpdyDb()
    #spdydb.query("select clientid, pushid from connected_push_id into outfile './clients.txt'")
    spdydb.query("select clientid, pushid from connected_push_id;")
