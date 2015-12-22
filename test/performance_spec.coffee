number_of_messages = 250
concurrency = 5
timeout = 5000

http = require "http"
http.globalAgent.maxSockets = 10000
throat = require('throat')

describe 'Router Performance', ->
  it 'should be fast', ->
    @timeout 30000
    console.log ""
    console.log ""
    console.log "####################################################"
    console.log "################# Performance Tests ################"
    console.log "####################################################"
    console.log ""
    console.log ""
    console.log "number_of_messages: #{number_of_messages}"
    console.log "concurrency: #{concurrency}"
    console.log "timeout: #{timeout}"
    console.log ""

      ## DIRECT TO SERVICE
    service = new Service("hello.service",
      service_fn: (context) -> bb.delay(5).then(-> {body: {hello: "service"}}),
    )


    ## THROUGH RESOURCE TOPIC EXCHANGE
    resource_name = random_resource()
    resource_path = "/v1/#{resource_name}"
    resource = new Resource(resource_name, resource_path)

    resource.show = (context) ->
      return bb.delay(5).then(-> {body: {hello: "resource"}})
    resource.show.public = true

    resource.create = (context) ->
      return bb.delay(5).then(-> {body: {hello: context.body.name}})
    resource.create.public = true

    service_name = random_service()
    resource_service = new ResourceService(service_name, [resource])

    # SETUP ROUTER
    router = new Router(
      logger: (->)
      timeout: timeout,
      resource_paths: {"/v1/hello": "hello.service"}
      additional_routes: [ ( (app) -> app.get('/test', (req, res) => res.send({ test: true }))) ]
    )

    bb.all([router.start(), service.start(), resource_service.start()])
    .then( ->
      console.log "Testing GET Sending Messages to Router"
      st = new Date().getTime()
      promises = [1..number_of_messages]
      #throat is used to limit the number of outgoing current connections as there is a limited number
      promises = promises.map(throat(concurrency, ->
        http_get("http://localhost:8080/test")
        .spread(( body, status) ->
          expect(status).to.equal(200)
          expect(body.test).to.be.true
        )
      ))

      bb.all(promises)
      .then( ->
        et = new Date().getTime()
        pe = (et-st)/number_of_messages
        console.log "#{pe}ms per message"
      )
    )
    .then( ->
      console.log "Testing GET Sending MEssages to Service"
      st = new Date().getTime()
      promises = [1..number_of_messages]
      #throat is used to limit the number of outgoing current connections as there is a limited number
      promises = promises.map(throat(concurrency, ->
        http_get("http://localhost:8080/v1/hello")
        .spread(( body, status) ->
          expect(status).to.equal(200)
          expect(body.hello).to.equal("service")
        )
      ))

      bb.all(promises)
      .then( ->
        et = new Date().getTime()
        pe = (et-st)/number_of_messages
        console.log "#{pe}ms per message"
      )
    )
    .then( ->
      console.log "Testing GET Sending MEssages to Resource"
      st = new Date().getTime()
      promises = [1..number_of_messages]
      #throat is used to limit the number of outgoing current connections as there is a limited number
      promises = promises.map(throat(concurrency, ->
        http_get("http://localhost:8080#{resource_path}")
        .spread(( body, status) ->
          expect(status).to.equal(200)
          expect(body.hello).to.equal("resource")
        )
      ))

      bb.all(promises)
      .then( ->
        et = new Date().getTime()
        pe = (et-st)/number_of_messages
        console.log "#{pe}ms per message"
      )
    )
    .then( ->
      console.log "Testing POST Sending MEssages to Resource"
      st = new Date().getTime()
      promises = [1..number_of_messages]
      #throat is used to limit the number of outgoing current connections as there is a limited number
      promises = promises.map(throat(concurrency, ->
        http_post("http://localhost:8080#{resource_path}", {name: "alchemy"})
        .spread(( body, status) ->
          expect(status).to.equal(200)
          expect(body.hello).to.equal("alchemy")
        )
      ))

      bb.all(promises)
      .then( ->
        et = new Date().getTime()
        pe = (et-st)/number_of_messages
        console.log "#{pe}ms per message"
      )
    )
    .finally( ->
      console.log ""
      console.log ""
      console.log "####################################################"
      console.log "########## END of Performance Tests ################"
      console.log "####################################################"
      console.log ""
      console.log ""

      bb.all([service.stop(), router.stop(), resource_service.stop()])
    )
