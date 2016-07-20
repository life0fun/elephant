#
# HTTP Router
# -----------
# Right now the router is simply an EventEmitter.
#

url = require 'url'
EventEmitter2 = require('eventemitter2').EventEmitter2
router = require ('router')

Logging = require('../common/logging')

#
# eventemitter2 : advanced event namespace match, TTL, etc.
# event is handled with eventemitter2.on event, handler.
# static url itself is unique name, so throw url is the same as
# throws an unique name event.
#

#
# when we say Router.route url, we basically asks url to be tokenized,
# foreach path seg token, event emitter emit a event.
# Whoever listen to the path, its event handler gets called to handle events.
#
# both spdy server and http server use this module.
# url path can not conflict !!!
#
class Router
    # class variable, to avoid this ref if declared as instance var.
    logger = Logging.getLogger "router"

    constructor: (@server) ->
        # event name can be wildcard matched, or namespace matched.
        @ee = new EventEmitter2 wildcard: true, delimiter: '?'
        @route = router()

    # dep inj the ref to server
    @create: (server) ->
        return new Router(server)


    # define all end point routers here
    @pushRouteV2: ->
        return '/application/v2/{pushId}'

    @registerRouteV2: ->
        return '/client/v2/register'

    @listenRouteV2: ->
        return '/client/v2/{pushId}'

    @ackRouteV2: ->
        return '/client/v2/ack'

    @refreshRouteV2: ->
        return '/client/v2/refresh'

    # Try the original route first for speed. If none exists,
    # recursively fall back until we find a route, if possible
    # This allows us to fully support HTML5 pushState 'mock routing'
    # across multiple single-page client
    # pass in the url for recursion
    routing: (requrl, req, res) ->
        # reqpath is an object {search:'?x=y', query:{x:'y', u:'v'},
        # pathname:'/connections', path:'/connections?x=y }
        # req.url is pure string '/connections?x=y'
        #reqpath = url.parse req.url, true
        logger.debug 'routing requrl : ', requrl

        # @ee.listeners(url) - @ee.listenersAny(url)
        # this recursive go thru all segments in the path and find the match.
        if @ee.listeners(requrl).length > 0   # requrl need to be ex
            logger.debug 'matching and emitting requrl:', requrl
            @ee.emit(requrl, req, res)   # exec listener on the other side
            return true
        else
            if requrl == '/'
                return false

        if requrl.indexOf('?') >= 0
            sr = requrl.split('?')
        else
            sr = requrl.split('/')

        sr.pop()  # pop the end element
        newUrl = sr.join('/')
        newUrl = '/' unless newUrl.length > 0
        @routing(newUrl, req, res)

    #
    # toss around this router object, different components can
    # augment the object with added router.on() method.
    # Augment the object without needed to class inheritant.
    #
    # cb will get the all the arguments that was emitted.
    #    emit(url, req, res) ==> cb(req, res)
    #
    on: (url, cb) ->
        logger.debug 'on url callback ', url
        if url.substring(0,1) == '/' && url.indexOf(' ') == -1
            @ee.on(url, cb)
        else
            throw new Error(url + ' Valid URLs must start with /')


    route: (req, res) ->
        @route(res,res)


    # handle get req on the url
    handleGet: (url, handler) ->
        logger.debug 'handle get :', url
        @route.get url, handler

    # handle post req
    handlePost: (url, handler) ->
        logger.debug 'handle post :', url
        @route.post url, handler

    # handle all types of requests to this end point, req.method has request method.
    handleAll: (url, handler) ->
        logger.debug "handle requests #{url}"
        @route.all url, handler


exports.Router = Router
