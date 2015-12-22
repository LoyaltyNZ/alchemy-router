# # Example 1: Sending a message to a resource
#
# Prerequisites:
# * RabbitMQ running
# * Memcached running

AlchemyResource = require 'alchemy-resource'
AlchemyRouter = require '../src/alchemy-router'

Promise = require 'bluebird'
request = Promise.promisifyAll(require("request"))


# Creating the `Hello` resource, whose path is '/hello'
hello_resource = new AlchemyResource.Resource("Hello", '/hello')

# The Hello resource implements `create` which takes a body and returns a string of the name
hello_resource.create = (context) ->
  {body: "Hello #{context.body.name}"}

# Make show action public so no authentication is needed
hello_resource.create.public = true

# create the router service
router = new AlchemyRouter()

# The resource service is created which contains the resource
service = new AlchemyResource.ResourceService('hello.service', [hello_resource])

# Start the Resource Service
Promise.all([service.start(), router.start()])
.then( ->
  # this will be sent to the router,
  # converted into a message and routed via the `resource.exchange`
  request.postAsync( "http://localhost:8080/hello", body: ['{"name": "Alice"}'])
)
.spread( (res, body) ->
  console.log(body) # "Hello Alice"
)
.finally( ->
  Promise.all([service.stop(), router.stop()])
)
