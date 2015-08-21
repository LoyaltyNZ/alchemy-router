describe 'HTTPEndpoint', ->

  describe '#constructor', ->
    it 'should work', ->
      new HTTPEndpoint()

  describe '#run', ->
    it 'should work', ->
      http_endpoint = new HTTPEndpoint()
      http_endpoint.run()
      .finally( ->
        http_endpoint.stop()
      )

  describe 'requests', ->
    it 'should receive calls', ->
      http_endpoint = new HTTPEndpoint()
      http_endpoint.run()
      .then( ->
        http_get("http://localhost:#{http_endpoint.port}/random_url")
      )
      .finally( ->
        http_endpoint.stop()
      )

    it 'should be handled with the given callback', ->
      httpHandler = (req, res) ->
        res.status 200
        res.send {hello: "world"}
        res.end()

      http_endpoint = new HTTPEndpoint(8080, '0.0.0', httpHandler)
      http_endpoint.run()
      .then( ->
        http_get("http://localhost:#{http_endpoint.port}/random_url")
      )
      .spread( (body, status) ->
        expect(body).to.deep.equal({hello: "world"})
      )
      .finally( ->
        http_endpoint.stop()
      )

  describe 'GET version', ->
    it 'should be handled with the given callback', ->
      http_endpoint = new HTTPEndpoint(8080, 'VERSION')
      http_endpoint.run()
      .then( ->
        http_get("http://localhost:#{http_endpoint.port}/version")
      )
      .spread( (body, status) ->
        expect(body).to.deep.equal({version: "VERSION"})
      )
      .finally( ->
        http_endpoint.stop()
      )


  describe '#setupChunk', ->
    it 'should call use on app', ->
      http_endpoint = new HTTPEndpoint()
      app = { use: sinon.spy() }

      http_endpoint.setupChunk(app)

      expect(app.use.called).to.be.true


  describe '#setupErrors', ->
    it 'should call use on app', ->
      http_endpoint = new HTTPEndpoint()
      app = { use: sinon.spy() }

      http_endpoint.setupErrors(app)

      expect(app.use.called).to.be.true


