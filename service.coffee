# Imports
_ = require("lodash")
Router = require("./src/router")
npm_package = require('./package.json')
ServiceResolver = require './src/service_resolver'
env = _.defaults(
  process.env,
  {
    AMQ_URI: 'amqp://localhost'
    PORT: 8080
    TIMEOUT: 5000
    ROUTES: '{}'
  }
)


routes = JSON.parse(env.ROUTES)

console.log routes
options = {
  logger: console.log
  version: npm_package.version
  amqp_uri: env.AMQ_URI
  port: env.PORT
  timeout: env.TIMEOUT
  middleware: [new ServiceResolver(routes)]
}

router = new Router(options)
router.start()
.catch( (err) ->
  console.error  "Unexpected Error"
  console.error err
  process.exit(1)
)
