bb = require 'bluebird'
express = require("express")
Util = require("#{__dirname}/util")

defaultHandler = (req, res) ->
  res.status 200
  res.send {}
  res.end()

sendHTTPResponse = (response, req, res) ->
  res.body = response.body
  res.status response.status_code
  res.header header, value for header, value of response.headers
  res.send response.body
  res.end()

sendNotFound =  (req,res) ->
  sendHTTPResponse {
    status_code: 404
    headers:
      'Content-Type': 'application/json'
    body: JSON.stringify(
      errors: [
        code: "platform.not_found"
        message: "The specified resource was not found"
        reference: res.path
      ]
    )
  }, req, res

class HTTPEndpoint

  constructor: (@port = 8080, @httpHandler = defaultHandler, @additional_middleware = [], @additional_routes = []) ->
    @app = express()
    @app.disable('etag')
    @app.disable('x-powered-by')
    @setupChunk(@app)

    for ar in @additional_routes
      ar(@app)

    for mw in @additional_middleware
      @app.use(mw)

    @setupErrors(@app)
    @app.route("*").all @httpHandler

  run:  ->
    deferred = bb.defer()

    @httpServer = @app.listen(@port, (err) ->
      return deferred.reject(err) if err
      deferred.resolve()
    )

    deferred.promise

  stop: ->
    deferred = bb.defer()

    if @httpServer
      @httpServer.close((err) ->
        return deferred.reject(err) if err
        deferred.resolve()
      )
      return deferred.promise
    else
      return bb.try(->)

  setupChunk: (app) ->
    app.use (req, res, next) ->
      req.body = ""
      req.setEncoding "utf8"
      req.on "data", (chunk) ->
        req.body += chunk

      req.on "end", ->
        next()

  setupErrors: (app) ->
    # Errors
    app.use (error, req, res, next) =>
      if error.name == "MiddlewareError" && res.headersSent
        res.end()
      else
        err =
          status_code: 500
          headers:
            'Content-Type': 'application/json; charset=utf-8'
          body: JSON.stringify {
            "errors": [{"code":"platform.fault", "message": "#{error.toString()}"}]
            "kind": "Errors",
            "created_at": (new Date()).toISOString()
            "id": Util.generateUUID()
            "interaction_id": res.get('x-interaction-id') || Util.generateUUID()
          }
        sendHTTPResponse(err, req, res)


HTTPEndpoint.sendHTTPResponse = sendHTTPResponse
HTTPEndpoint.sendNotFound = sendNotFound

module.exports = HTTPEndpoint
