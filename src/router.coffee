HTTPEndpoint = require("./http_endpoint")

Util = require("./util")
bb =   require 'bluebird'
_ =    require("lodash")

alchemy = require("alchemy")
Service = alchemy.Service

class Router

  constructor: (options = {}) ->
    @config = _.defaults(
      options,
      {
        logger: console.log
        version: "0.0.0"
        amqp_uri: 'amqp://localhost'
        port: 8080
        timeout: 5000
        middleware: []
      }
    )

    #routes = {
    #  path: service_queue
    #  "/v1/sessions": "service.authentication"
    #}

  start: ->
    @router_service = new Service('alchemy_router', {
      service_queue: false
      amqp_uri: @config.amqp_uri
      timeout: @config.timeout
    })

    callbacks = @config.middleware.map( (mw) -> mw.callback)
    @http = new HTTPEndpoint(@config.port, @config.version, @onHTTPRequest, callbacks)

    promises = @config.middleware.map( (mw) -> mw.start())
    bb.all(promises)
    .then( =>
      @router_service.start()
    )
    .then( =>  
      @http.run()
    )

  stop: ->
    #stop taking calls, then disconnect all resources
    @http.stop()
    .then( =>
      @router_service.stop()
    )
    .then(=>
      promises = @config.middleware.map( (mw) -> mw.stop())
      bb.all(promises)
    )

  # Handle an HTTP request from outside the platform
  onHTTPRequest: (req, res) =>

    # Filter out headers sent with x-interaction-id (as this is used internally to track the request)
    # Node lower cases headers and strips trailing/leading whitespace so we just
    # need to check for headers with underscores instead of dashes
    for key of req.headers
      if /^x(-|_)interaction(-|_)id$/.test(key)
        delete req.headers[key]

    # we post the service onto the
    httpRequest =
      session_id: req.get 'X-Session-ID'
      scheme: req.protocol
      host: req.hostname
      port: req.port || 80
      path: req.path
      query: req.query
      verb: req.method
      headers: req.headers
      body: req.body

    transaction =
      req: req
      res: res
      httpRequest: httpRequest
      createdOn: Date.now()
      ip_address: req.get('x-forwarded-for') || req.connection.remoteAddress


    transaction_promise = @router_service.sendMessageToServiceOrResource(req.service, httpRequest)
    transaction.messageId = transaction_promise.messageId
    transaction.interactionId = transaction_promise.transactionId

    transaction_promise
    .spread( (msg, content) =>
      transaction.response =
        status_code: content.status_code
        headers: content.headers
        body: content.body
        duration: Date.now() - transaction.createdOn
      
      @config.logger Util.getHTTPLogLine(transaction.req, transaction.response.status_code, transaction.response.duration)
      HTTPEndpoint.sendHTTPResponse(transaction.response, transaction.req, transaction.res)
      true

    )
    .catch(Service.MessageNotDeliveredError, =>
      HTTPEndpoint.sendNotFound(transaction.req, transaction.res)
    )
    .catch(Service.TimeoutError, =>
      response =
        status_code: 408
        headers:
          'Content-Type': 'application/json'
        body: JSON.stringify
          errors: [
            code:'platform.timeout'
            message: "Request timeout (#{@config.timeout}ms)"
          ]

      HTTPEndpoint.sendHTTPResponse(response, transaction.req, transaction.res)
    )

module.exports = Router
