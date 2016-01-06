# Alchemy Router

Alchemy Router is the gateway from HTTP to Alchemy Resources for the Alchemy Micro-services Framework. It can be used directly as an application or as a library to build and customise using [express](http://expressjs.com/en/guide/using-middleware.html) middleware and routes.

## Router Application

To install the alchemy router run:

```
npm install -g alchemy-router
```

Then execute:

```
alchemy-router
```

You can configure the router with the environment variables:

1. `AMQP_URI`  *default `'amqp://localhost'`*: the location of the (RabbitMQ) AMQP server
2. `PORT` *default `8080`*: the port to open the HTTP server on
3. `TIMEOUT` *default `5000`*: the router will return a `408` timeout response after waiting for the service.
4. `PATHS` *default `'{}'`*: the JSON string that matches service queues directly with paths, e.g. `PATHS='{"/hello" : 'service.hello'}'` will direct all calls that start with path `/hello` to the queue `service.hello`.

### Docker

This repository also comes with an example Docker container, which is published to the docker hub.

Build the Docker container with:

```
docker build -t alchemy-router:$VERSION .
```

Push the docker container with:

```
docker push alchemy-router:$VERSION
```

Run the docker container:

```
docker run -it -p 8080:8080 alchemy-router:$VERSION
```

## Router Library

To install the router as a library:

```
npm install alchemy-router
```

To start a router:

```coffeescript
AlchemyRouter = require 'alchemy-router'
router = new AlchemyRouter()
router.start()
```

### Middleware

Middleware can be used to extend the routers with custom functionality. Middleware are objects with a `callback` that is an [express middleware](http://expressjs.com/en/guide/using-middleware.html) callback function, an optional `start` and `stop` functions that can control the life cycle of the middleware.

```coffeescript
logging_middleware = {
  callback: (req, res, next) ->
    console.log req.path
    next()

  # promise to start middleware
  start: -> true

  # promise to stop middleware
  stop: -> true
}

AlchemyRouter = require 'alchemy-router'
router = new AlchemyRouter()
router.start({
  middleware: [logging_middleware]
})
```

### Additional Routes

Additional hard-coded routes can be added to the router, these can be useful for health-checks, logging, versioning ... *Note: these routes will override any service routes.*

```coffeescript
hello_route = (app) ->
  app.get '/hello', (req, res) =>
    res.send {say: "hello"}
    res.end()

AlchemyRouter = require 'alchemy-router'
router = new AlchemyRouter()
router.start({
  additional_routes: [hello_route]
})
```

## Documentation

*This Alchemy-Router documentation is generated with [docco](https://jashkenas.github.io/docco/) from its annotated source code.*

The Alchemy-Router package exports [Router](./src/router.html):

    module.exports = require("./router")

## Examples

* [Sending a message to a Resource](./examples/example_1_send_message.html)

