# Alchemy Router

The alchemy router is an application that takes http-requests and translates them into an alchemy packet to be sent to a resource via rabbitmq. Once the resource has returned a value it will then return the http call with the results.

Its is intended to be either used directly as an application in an alchemy based platform, or extended to fulfil a custom purpose.

The core philosophy of this package is "do one thing, do it well", and the one thing this does is take http requests and forward them to resources.


### Middleware

The recommended way of extending the router is through additional middleware.

By passing instances of middleware to `middleware` config, where each instance implements two methods:

```
class Middleware 
  callback: (req, res, next) =>
    #express callback, call next() when done
    next()

  start: ->
    #promise that all the parts have started
```


