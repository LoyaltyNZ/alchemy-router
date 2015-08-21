number_of_messages = 500
concurrency = 5
timeout = 5000

http = require "http"
http.globalAgent.maxSockets = 10000
throat = require('throat')

describe 'Router Performance', ->
  it 'should be fast', ->
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
      service_fn: (payload) -> bb.delay(5).then(-> {body: {hello: "service"}}),
    )
    

    ## THROUGH RESOURCE TOPIC EXCHANGE
    resource_name = random_resource()
    resource_path = "/v1/#{resource_name}"
    resource = new Resource(resource_name, resource_path)

    resource.show = (payload) ->
      return bb.delay(5).then(-> {body: {hello: "resource"}})
    resource.show.public = true

    service_name = random_service()
    resource_service = new ResourceService(service_name, [resource])

    # SETUP ROUTER
    router = new Router(
      logger: (->)
      timeout: timeout, 
      middleware: [new ServiceResolver({"/v1/hello": "hello.service"})]
    )

    bb.all([router.run(), service.start(), resource_service.start()])
    .then( ->
      console.log "Testing Sending MEssages to Service"
      st = new Date().getTime()
      promises = [1..number_of_messages]
      #throat is used to limit the number of outgoing current connections as there is a limited number
      promises = promises.map(throat(concurrency, -> 
        http_get("http://localhost:#{router.config.port}/v1/hello")
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
      console.log "Testing Sending MEssages to Resource"
      st = new Date().getTime()
      promises = [1..number_of_messages]
      #throat is used to limit the number of outgoing current connections as there is a limited number
      promises = promises.map(throat(concurrency, -> 
        http_get("http://localhost:#{router.config.port}#{resource_path}")
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
