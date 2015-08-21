process.env.NODE_ENV = 'test'

#Require test packages
require('dotenv').load()
chai = require 'chai'
chaiAsPromised = require("chai-as-promised")
chai.use(chaiAsPromised);

global.sinon = require 'sinon'


#require packages
global.bb = require 'bluebird'
bb.longStackTraces()

request = bb.promisify(require("request"))

bb.onUnhandledRejectionHandled( -> )
bb.onPossiblyUnhandledRejection( -> )
global._ = require 'lodash'


global.expect = chai.expect;
global.assert = chai.assert;

#Alchemy Imports

alchemy = require("alchemy")
global.Service = alchemy.Service
global.SessionClient = alchemy.SessionClient
global.Resource = alchemy.Resource
global.ResourceService = alchemy.ResourceService

# Local imports

alchemy_router = require '../src/alchemy_router'
global.Util = alchemy_router.Util
global.HTTPEndpoint = alchemy_router.HTTPEndpoint
global.Router = alchemy_router.Router
global.ServiceResolver = alchemy_router.ServiceResolver


global.random_name = (prefix) ->
  "#{prefix}_#{_.random(0, 99999999)}"

global.random_resource = ->
  random_name("resource")

global.random_service = ->
  random_name("random_service")

parse_response_into_json_status = (response) ->
  [resp, body] = response
  [JSON.parse(body.toString()), resp.statusCode ]


global.http_get_with_headers = (url, headers) ->
  req =
    url: url
    method: "GET"
    agent: false
    headers: headers
  request(req)
  .then(parse_response_into_json_status)

global.http_get = (url) ->
  req =
    url: url
    method: "GET"
    agent: false
  request(req)
  .then(parse_response_into_json_status)

global.http_post = (url, body) ->
  req = 
    url: url
    method: "POST"
    agent: false
    headers: { "Content-Type": "application/json" }
    charset: 'UTF-8'
    body: [JSON.stringify(body)]

  qhttp.request(req)
  .then(parse_response_into_json_status)
