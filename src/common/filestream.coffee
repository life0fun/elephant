#
# File Stream helper
# -----------
#

fs = require('fs')
path = require('path')
url = require 'url'
EventEmitter2 = require('eventemitter2').EventEmitter2

#
# All utils are static function within the module
#

class FileStream

    # dump client info dictionary, props clientId and workerId
    @dumpCollection : (filename, collection) ->
        logfile = path.resolve filename
        fos = fs.createWriteStream logfile
        fos.once 'open', (fd) ->
            for key in Object.keys(collection)
                fos.write collection[key].clientId
                fos.write '\t'
                fos.write collection[key].workerId
                fos.write '\n'
            fos.end()

    # dump client info array, props clientid and workerid.
    # client info json object props are lower case : db column is low case.
    @dumpArray : (filename, array) ->
        logfile = path.resolve filename
        fos = fs.createWriteStream logfile
        fos.once 'open', (fd) ->
            for e in array
                fos.write e.clientid
                fos.write '\t'
                fos.write e.workerid
                fos.write '\n'
            fos.end()

exports.FileStream = FileStream
