# # Alchemy Router

# ## Imports
# * `bluebird` is the promises library
# * `lodash` is used as a general purpose utility library
# * `express` is the framework used to handle HTTP requests
# * `http` used to create the express server
# * `Service` is used as a service to communicate with resources
# * `MessageNotDeliveredError` used if a message is returned from RabbitMQ
# * `TimeoutError` used if a service times-out
bb                       = require("bluebird")
_                        = require("lodash")
http                     = require("http")
express                  = require("express")
Service                  = require("alchemy-ether")
MessageNotDeliveredError = Service.MessageNotDeliveredError
TimeoutError             = Service.TimeoutError

# ## Router
class Router

  # `constructor` takes an `options` object with the keys:
  # 1. `amqp_uri`: the URI to AMQP server
  # 2. `port`: the port to run the HTTP server on
  # 3. `timeout`: the time till a service call times-out
  # 4. `resource_paths`: explicit paths to services e.g. `{'/v1/test': 'service.test'}`
  # 5. `middleware`: a list of express middleware to be added
  # 6. `additional_routes`: a list of additional routes to be added to the HTTP server
  #
  # The instance variables are:
  # 1. `@options` stores the instance options
  # 2. `@router_service` is the empty Alchemy Service used to message other Alchemy Resources
  # 3. `@http_server` is the HTTP server initialised with the `build_server` function
  #
  constructor: (options = {}) ->
    @options = _.defaults(
      options,
      {
        amqp_uri: 'amqp://localhost'
        port: 8080
        timeout: 5000
        resource_paths: {}
        middleware: []
        additional_routes: []
      }
    )

    @router_service = new Service('router.service', {
      service_queue: false
      amqp_uri: @options.amqp_uri
      timeout: @options.timeout
    })

    @http_server = @build_server()

  # #### HTTP Server functions

  # `build_server` creates the express application and returns an HTTP server that uses it
  #
  # This function
  # 1. builds the express app
  # 2. sets up the middleware of the application
  # 3. adds the additional routes
  # 4. adds the default route handler `@on_HTTP_request` that will be called when trying to call a service
  # 5. returns a "promisified" HTTP server instance
  build_server: () ->
    express_app = express()
    express_app.disable('etag')
    express_app.disable('x-powered-by')

    @setup_middleware(express_app)

    for ar in @options.additional_routes
      ar(express_app)

    express_app.route("*").all @on_HTTP_request

    bb.promisifyAll(http.createServer(express_app))

  # `setup_middleware` adds the express router middleware
  #
  # The added middleware is:
  # 1. `@body_mw` reads the request body and attaches it to the request
  # 3. `@resource_path_mw` checks to see if a path is hard-coded in the `@options.resource_paths` object
  # 4. adds the `@options.middleware` callbacks to the express application
  # 5. `@error_mw` handles reporting errors and returning errors to the caller
  setup_middleware: (express_app) ->
    express_app.use @body_mw
    express_app.use @resource_path_mw

    for mw in @options.middleware.map( (mw) -> mw.callback)
      express_app.use(mw)

    express_app.use @error_mw


  # `body_mw` reads the request body and attaches it to the request
  body_mw: (req, res, next) ->
    req.body = ""
    req.setEncoding "utf8"
    req.on "data", (chunk) ->
      req.body += chunk
    req.on "end", ->
      next()


  # `resource_path_mw` checks to see if a path is hard-coded in the `@options.resource_paths` object
  resource_path_mw: (req, res, next) =>
    for path, sname of @options.resource_paths
      if _.startsWith(req.path, path)
        req.service = sname
    next()

  # `error_mw` handles reporting errors and returning errors to the caller
  error_mw: (err, req, res, next) ->
    console.error err
    Router.send_HTTP_response({
      status_code: 500
      headers: {'Content-Type': 'application/json; charset=utf-8'}
      body:   {
        kind:           "Errors",
        id:             Service.generateUUID()
        created_at:     (new Date()).toISOString(),
        errors: ["Unknown Error"]
      }
    }, res)

  # `on_HTTP_request` converts all requests to the router into Alchemy Service or ResourceService messages
  #
  # First the `http_request` packet is created from the express request
  #
  # If the request has `service` attached (either from additional or `resource_path_mw` middleware)
  # it sends the message directly to the service, otherwise sends it to the resource.
  #
  # The message is sent then:
  # * if the message is successful the response to the caller is the content
  # * if a `MessageNotDeliveredError` is caught then the response to the caller is 404 `Bam.not_found`
  # * if a `TimeoutError` is caught then the response to the caller is 408 `Bam.timeout_error`
  on_HTTP_request: (req, res) =>
    http_request = {
      scheme: req.protocol
      host: req.hostname
      port: req.port || 80
      path: req.path
      query: req.query
      verb: req.method
      headers: req.headers
      body: req.body
    }

    if req.service
      send_message = @router_service.send_request_to_service( req.service, http_request )
    else
      send_message = @router_service.send_request_to_resource( http_request )

    send_message
    .then( (content) =>
      Router.send_HTTP_response(content, res)
    )
    .catch(MessageNotDeliveredError, =>
      Router.send_HTTP_response({
        status_code: 404
        headers: {'Content-Type': 'application/json; charset=utf-8'}
        body:   {
          kind:           "Errors",
          id:             Service.generateUUID()
          created_at:     (new Date()).toISOString(),
          errors: ["#{http_request.path} not found"]
        }
      }, res)
    )
    .catch(TimeoutError, =>
      Router.send_HTTP_response({
        status_code: 408
        headers: {'Content-Type': 'application/json; charset=utf-8'}
        body:   {
          kind:           "Errors",
          id:             Service.generateUUID()
          created_at:     (new Date()).toISOString(),
          errors: ["Timeout after #{@options.timeout}ms"]
        }
      }, res)
    )

  # `send_HTTP_response` responds over HTTP to the caller
  #
  # The message must contain a `body`, a `status_code` and an object of `headers`
  @send_HTTP_response: (message, res) ->
    res.body = message.body
    res.status message.status_code
    res.header header, value for header, value of message.headers
    res.send message.body
    res.end()

  # #### Life Cycle

  # `start` starts the router:
  # 1. starting the middleware
  # 2. starting the router service
  # 3. start receiving HTTP requests
  start: ->
    start_middleware = bb.all(@options.middleware.map( (mw) -> mw.start() if mw.start))

    start_middleware
    .then( =>
      @router_service.start()
    )
    .then( =>
      @http_server.listenAsync(@options.port)
    )

  # `stop` stops the router from working:
  # 1. stop receiving HTTP calls
  # 2. stop the service. This will wait till all the messages have been processed
  # 3. stop the middleware
  stop: ->
    @http_server.closeAsync()
    .then( =>
      @router_service.stop()
    )
    .then(=>
      promises = @options.middleware.map( (mw) -> mw.stop() if mw.stop)
      bb.all(promises)
    )

module.exports = Router