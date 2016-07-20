#!/usr/bin/env coffee

class MapTest
    constructor : (@size) ->
        @map = {}

    @create : (size) ->
        return new MapTest size

    fill : ->
        for i in [0..@size]
            @map[i] = {}
            @map[i].key = 'key-' + i
            @map[i].val = 'val-' + i

    verify : ->
        for i in [0..1000]
            start = Date.now()
            entry = @map[i*1000]
            end = Date.now()
            console.log 'entry : ', i, entry.key, entry.val, ' cost:', end-start, 'ms'

    keys : ->
        start = Date.now()
        size = Object.keys(@map).length
        end = Date.now()
        console.log 'total keys:', size, ' iterate cost time:', end-start, 'ms'

    hasKey : (key) ->
        start = Date.now()
        exist = @map.hasOwnProperty(key)
        end = Date.now()
        console.log 'hasOwnProperty ', key, exist, @map[key], end-start, 'ms'

module.exports.MapTest = MapTest

#
# unit test
#
maptest = MapTest.create 2*1000*1000
maptest.fill()
maptest.verify()
maptest.keys()
maptest.hasKey('100000')
