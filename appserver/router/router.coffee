#
# HTTP Router
# -----------
# Right now the router is simply an EventEmitter.
#

url = require 'url'
EventEmitter2 = require('eventemitter2').EventEmitter2
router = require ('router')

Node = require('../common/root')

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
    constructor: (@server) ->
        # event name can be wildcard matched, or namespace matched.
        @ee = new EventEmitter2 wildcard: true, delimiter: '?'
        @route = router()

    # dep inj the ref to server
    @create : (server) ->
        Node.log 'Router : created'
        return new Router(server)

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
        Node.log 'route on requrl : ', requrl

        # TODO allow for widcards with listeners =
        # @ee.listeners(url) - @ee.listenersAny(url)
        # this recursive go thru all segments in the path and find the match.
        if @ee.listeners(requrl).length > 0   # requrl need to be ex
            Node.log 'matching and emitting requrl:', requrl
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
        Node.log 'Router on :', url
        if url.substring(0,1) == '/' && url.indexOf(' ') == -1
            @ee.on(url, cb)
        else
            throw new Error(url + ' Valid URLs must start with /')


    route : (req, res) ->
        @route(res,res)

    #
    # handle get req on the url
    handleGet : (url, getHandler) ->
        Node.log 'handle get :', url
        @route.get url, getHandler

    #
    # handle post req
    #
    handlePost : (url, postHandler) ->
        Node.log 'handle post :', url
        @route.post url, postHandler


exports.Router = Router
