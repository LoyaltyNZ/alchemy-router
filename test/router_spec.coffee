describe 'Router', ->

  describe '#constructor', ->
    it 'should work', ->
      new Router()

  describe '#start #stop', ->
    it 'should work', ->
      router = new Router()
      router.start()
      .finally( ->
        router.stop()
      )

    it 'should still process waiting messages after stopping', ->
      resource_name = random_resource()
      resource_path = "/v1/#{resource_name}"
      resource = new Resource(resource_name, resource_path)

      resource.show = (payload) ->
        return bb.delay(500).then( -> { body: {"hello": "stop"} })
      resource.show.public = true

      service_name = random_service()
      resource_service = new ResourceService(service_name, [resource])

      router = new Router(
        timeout: 1000,
        resource_paths: {resource_path: service_name}
      )

      bb.all([router.start(), resource_service.start()])
      .then( ->
        promises = []
        promises.push http_get("http://localhost:8080#{resource_path}")
        promises.push bb.delay(100).then( -> router.stop(); true)
        bb.all(promises)
      )
      .spread( (req, stop) ->
        [body, status] = req
        expect(status).to.equal(200)
        expect(body.hello).to.equal("stop")
      )
      .finally( ->
        bb.all([resource_service.stop()])
      )

  describe "additional routes", ->
    it 'adding an additional route should work', ->

      version_endpoint = (app) ->
        app.get '/version', (req,res) =>
          res.send version: "VERSION"
          res.end()

      router = new Router(additional_routes: [version_endpoint])
      router.start()
      .then( ->
        http_get("http://localhost:8080/version")
      )
      .spread( (body, status) ->
        expect(body).to.deep.equal({version: "VERSION"})
      )
      .finally( ->
        router.stop()
      )

  describe 'middleware', ->

    it 'should allow for additional middleware', ->
      toggle = false

      middleware = {
        callback: (req,res,next) -> toggle = true; next();
        start: -> true
        stop: -> true
      }

      router = new Router(middleware: [middleware])
      router.start()
      .then( ->
        http_get("http://localhost:8080/random_url")
      )
      .spread( (body, status) ->
        expect(toggle).to.be.true
      )
      .finally( ->
        router.stop()
      )

    it 'should 500 on middleware errors', ->
      middleware = {
        callback: (req,res,next) -> throw 'BAD EXCEPTION';
      }

      router = new Router(middleware: [middleware])
      router.start()
      .then( ->
        http_get("http://localhost:8080/random_url")
      )
      .spread( (body, status) ->
        expect(status).to.equal 500
      )
      .finally( ->
        router.stop()
      )

  describe 'resources', ->
    it 'should route to resources explicitly set', ->
      resource_name = random_resource()
      resource_path = "/v1/#{resource_name}"
      resource = new Resource(resource_name, resource_path)

      resource.show = (payload) ->
        return { body: {"hello": "world1"} }
      resource.show.public = true

      service_name = random_service()
      resource_service = new ResourceService(service_name, [resource])

      router = new Router(
        timeout: 100,
        resource_paths: {resource_path: service_name}
      )

      bb.all([router.start(), resource_service.start()])
      .then( ->
        http_get("http://localhost:8080#{resource_path}")
      )
      .spread( (body,status) ->
        expect(status).to.equal(200)
        expect(body.hello).to.equal("world1")
      )
      .finally( ->
        bb.all([resource_service.stop(), router.stop()])
      )

    it 'should route to resources via exchange', ->
      resource_name = random_resource()
      resource_path = "/v1/#{resource_name}"
      resource = new Resource(resource_name, resource_path)

      resource.show = (payload) ->
        return { body: {"hello": "world2"} }
      resource.show.public = true

      service_name = random_service()
      resource_service = new ResourceService(service_name, [resource])

      router = new Router(timeout: 100)

      bb.all([router.start(), resource_service.start()])
      .then( ->
        http_get("http://localhost:8080#{resource_path}")
      )
      .spread( (body,status) ->
        expect(status).to.equal(200)
        expect(body.hello).to.equal("world2")
      )
      .finally( ->
        bb.all([resource_service.stop(), router.stop()])
      )

    it 'should send to the right place', ->

      ## DIRECT TO SERVICE
      service = new Service("hello.service",
        service_fn: (payload) -> bb.delay(1).then(-> {body: {hello: "service"}}),
      )

      ## THROUGH RESOURCE TOPIC EXCHANGE
      resource_name = random_resource()
      resource_path = "/v1/#{resource_name}"
      resource = new Resource(resource_name, resource_path)

      resource.show = (payload) ->
        return bb.delay(1).then(-> {body: {hello: "resource"}})
      resource.show.public = true

      service_name = random_service()
      resource_service = new ResourceService(service_name, [resource])

      # SETUP ROUTER
      router = new Router(
        resource_paths: {"/v1/hello": "hello.service"}
      )

      bb.all([router.start(), service.start(), resource_service.start()])
      .then( ->
        http_get("http://localhost:8080#{resource_path}")
      )
      .spread( (body,status) ->
        expect(status).to.equal(200)
        expect(body.hello).to.equal("resource")
      )
      .then( ->
        http_get("http://localhost:8080/v1/hello")
      )
      .spread( (body,status) ->
        expect(status).to.equal(200)
        expect(body.hello).to.equal("service")
      )
      .finally( ->
        bb.all([service.stop(), router.stop(), resource_service.stop()])
      )

  describe 'routes', ->
    it 'should return 404 for unregistered service', ->
      router = new Router()
      router.start()
      .then( ->
        http_get("http://localhost:8080/random_url")
      )
      .spread( (body,status) ->
        expect(status).to.equal(404)
      )
      .finally( ->
        router.stop()
      )

    it 'should timeout for registered unhandled service', ->
      router = new Router(
        timeout: 100,
        resource_paths: {"/v1/service": "service.location"}
      )
      service = new Service("service.location")
      service.start().then( -> service.stop())
      .then( ->
        router.start()
      )
      .then( ->
        http_get("http://localhost:8080/v1/service")
      )
      .spread( (body,status) ->
        expect(status).to.equal(408)
      )
      .finally( ->
        router.stop()
      )

    it 'should return a response from a service (including with identifier)', ->
      service = new Service("hello.service", service_fn: (payload) -> {body: {hello: "world"}})

      router = new Router(
        timeout: 100,
        resource_paths: {"/v1/hello": "hello.service"}
      )

      bb.all([router.start(), service.start()])
      .then( ->
        http_get("http://localhost:8080/v1/hello")
      )
      .spread( (body,status) ->
        expect(status).to.equal(200)
        expect(body.hello).to.equal("world")
      )
      .then( ->
        http_get("http://localhost:8080/v1/hello/identifier")
      )
      .spread( (body,status) ->
        expect(status).to.equal(200)
        expect(body.hello).to.equal("world")
      )
      .finally( ->
        bb.all([service.stop(), router.stop()])
      )


    # x-interaction-id is a header used to follow the path of a single call so is
    # used internally to track service calls, and externally for a clients logging of a single call
    # Allowing a client to pass in a interaction ID may violate "1 call, 1 interaction id" rule
    it 'should filter out headers equivalent to x-interaction-id, set new interaction id', ->
      interaction_headers = {
        'X-Interaction-Id': 'bla',
        'x-interaction-id': 'bla',
        'X-INTERACTION-ID': 'bla',
        'X_Interaction_Id': 'bla',
        'x_interaction_id': 'bla',
        'X_INTERACTION_ID': 'bla',
        'x-interaction_id': 'bla',
        'x_interaction-id': 'bla',
        'X_interaction_Id': 'bla'
      }

      service = new Service("hello.service", service_fn: (payload)->
        # No extra headers are going through which might think are
        # x-interaction-id
        expect(['x-interaction-id', 'host', 'connection']).to.have.members(Object.keys(payload.headers))
        expect(Object.keys(payload.headers).length).to.equal(3)

        # None of the passed interaction id's managed to sneak through
        expect(payload.headers['x-interaction-id']).to.not.equal('bla')
        {body: {hello: "world"}}
      )

      router = new Router(
        timeout: 500,
        resource_paths: {"/v1/hello": "hello.service"}
      )

      bb.all([router.start(), service.start()])
      .then( ->
        http_get_with_headers(
          "http://localhost:8080/v1/hello",
          interaction_headers
        )
      )
      .spread( (body,status) ->
        expect(status).to.equal(200)
        expect(body.hello).to.equal("world")
      )
      .finally( ->
        bb.all([service.stop(), router.stop()])
      )
