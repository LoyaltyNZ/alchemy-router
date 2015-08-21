_ = require 'lodash'

class ServiceResolver
  constructor: (@routes) ->

  callback: (req, res, next) =>
    service_queue_name = null
    for path, sname of @routes
      if _.startsWith(req.path, path)
        service_queue_name = sname

    req.service = service_queue_name
    next()

  start: ->
    true

  stop: ->
    true
    

module.exports = ServiceResolver