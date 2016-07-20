#
# HTTP Basic Auth encode/decode utility functions.
#
class BasicAuth

    ###
    # Encoding username and password for use in an 'Authorize' HTTP header.
    #
    # @returns {string} basic auth encoded string.
    ###
    @encode: (username, password) ->
        return new Buffer("#{username}:#{password}").toString('base64')

    ###
    # Decode username and password from an 'Authorize' HTTP header.
    #
    # @returns {string|string} username and password.
    ###
    @decode: (basicAuth) ->
        return new Buffer(basicAuth, 'base64').toString('utf8').split(":")


module.exports = BasicAuth
