# import lodash and alchemy-router
_ = require("lodash")
Router = require("./src/alchemy-router")

# extract the environment variables and add defaults
env = _.defaults(
  process.env,
  {
    AMQP_URI: 'amqp://localhost'
    PORT: 8080
    TIMEOUT: 5000
    PATHS: '{}'
  }
)

# Remove escaped values from the PATHS environment variable
env.PATHS = env.PATHS.replace(/\\/g, '')

# Parse the PATHS variable and add the rest of the variable
options = {
  resource_paths: JSON.parse(env.PATHS)
  amqp_uri: env.AMQP_URI
  port: env.PORT
  timeout: env.TIMEOUT
}

# initialise the Router
router = new Router(options)

# start the router, if there are problems log the problems and exit
router.start()
.catch( (err) ->
  console.error  "Unexpected Error"
  console.error err
  process.exit(1)
)
