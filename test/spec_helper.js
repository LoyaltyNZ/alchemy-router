var chai, parse_response_into_json_status, request;

process.env.NODE_ENV = 'test';

//Require test packages
chai = require('chai');

global.sinon = require('sinon');

//require packages
global.bb = require('bluebird');

bb.longStackTraces();

request = bb.promisify(require("request"));

bb.onUnhandledRejectionHandled(function() {});
bb.onPossiblyUnhandledRejection(function() {});

global._ = require('lodash');
global.expect = chai.expect;
global.assert = chai.assert;

global.Service = require("alchemy-ether");

// Local imports
global.Router = require('../src/router');

global.random_name = function(prefix) {
  return `${prefix}_${_.random(0, 99999999)}`;
};

global.random_resource = function() {
  return random_name("resource");
};

global.random_service = function() {
  return random_name("random_service");
};

parse_response_into_json_status = function(response) {
  var body, resp;
  [resp, body] = response;
  return [JSON.parse(body.toString()), resp.statusCode];
};

global.http_get_with_headers = function(url, headers) {
  var req;
  req = {
    url: url,
    method: "GET",
    agent: false,
    headers: headers
  };
  return request(req).then(parse_response_into_json_status);
};

global.http_get = function(url) {
  var req;
  req = {
    url: url,
    method: "GET",
    agent: false
  };
  return request(req).then(parse_response_into_json_status);
};

global.http_post = function(url, body) {
  var req;
  req = {
    url: url,
    method: "POST",
    agent: false,
    headers: {
      "Content-Type": "application/json"
    },
    charset: 'UTF-8',
    body: [JSON.stringify(body)]
  };
  return request(req).then(parse_response_into_json_status);
};

