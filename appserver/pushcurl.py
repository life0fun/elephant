#!/usr/bin/env python

"""
  this file provide an simple command line post request equivalent to curl.

  Usage: ./pushcurl.py <client-id> <push-id> <msg>
"""

import json
import base64
import requests
from optparse import OptionParser

#
# cat /tmp/push | POST -sedU -H 'Content-Length: 133'
#   -H 'Authorization: Basic FEBhVt9sCg2Xf1SQ2tWW2jhzgK4rQVss0qUmgfFPUQVIsGFiwznN8AxJ9Thx4x7HZY1vZgq929S86lZRC9EzMg=='
#   -c 'application/json' http://elephant-dev.colorcloud.com/application/v2/3Kfil21grTLOj3dQD0M7R8iz1Mo=
#
def curlpush(puid, msg, elephant):
    ''' execute curl command in the following format
        curl --header "authorization:Basic clid-a-31687-3" -d 'hello puid-a-31687-3!' http://elephant-dev.colorcloud.com/api/application/v1/puid-a-31687-3
    '''
    #eleurl = 'http://elephant-cte.colorcloud.com/api/application/v1/'
    localurl = 'https://localhost.colorcloud.com:8443/application/v2/'
    #localurl = 'https://elephant-cte.colorcloud.com:8443/application/v2/'

    url = localurl + puid
    if elephant:
        url = eleurl + puid

    pushmsg = {
        "message": "hello world",
        "callback": {
            "url": "https://example-wrong.com",
            "username": "user",
            "password": "password"
        }
    }
    pushmsgstr = json.dumps(pushmsg)
    print 'posting to :', url, ' data: ', pushmsgstr

    headers = {}
    headers['authorization'] = 'Basic '+ base64.b64encode("default:secret")
    if localurl.find("v1") >= 0:
        headers['content-type'] = 'text/plain'
    else:
        headers['content-type'] = 'application/json'
        headers['accept'] = 'application/json'

    req = requests.post(url, data=pushmsgstr, headers=headers, verify=False)
    print 'response : ', req, req.text

if __name__ == '__main__':
    parser = OptionParser()
    parser.add_option('-e', '--elephant', action='count', dest='elephant', default=0,
                      help='connect to elephant server')

    parser.add_option('-l', '--localserver', action='count', dest='local', default=0,
                      help='connect to local server')

    options, args = parser.parse_args()

    if len(args) < 1:
        print 'Usage: ./pushcurl.py push-id hello-world'
        exit(1)

    id = args[0]
    if len(args) < 2:
        puid = 'puid-' + id
        msg = args[1]
    else:
        puid = args[0]
        msg = args[1]

    elephant = False
    if options.elephant:
        elephant = True

    print 'pushing data to ', puid, msg
    curlpush(puid, msg, elephant)
