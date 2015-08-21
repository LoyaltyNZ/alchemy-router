uuid = require 'node-uuid'
class Util

  @isIPAddress: (str) -> 
    /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/.test(str)

  @generateUUID: ->
    uuid.v4().replace(/-/g,'')

  @getHTTPLogLine: (req, status_code, duration) ->
    d = new Date()
    x = "#{d.toISOString()} - #{req.method} #{req.protocol}://#{req.hostname}"
    x += ":#{req.port}" if req.port?
    x += "#{req.originalUrl} [#{status_code}] #{duration}ms"
    x

  @getAMQPLogLine: (req, queue) ->
    d = new Date()
    x = "#{d.toISOString()} - #{req.method} #{req.protocol}://#{req.hostname}"
    x += ":#{req.port}" if req.port?
    x += "#{req.originalUrl} -> #{queue}"
    x

module.exports = Util
