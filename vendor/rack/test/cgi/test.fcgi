#!/usr/bin/env ruby
# -*- ruby -*-

require 'rack'
require '../testrequest'

Rack::Handler::FastCGI.run(Rack::Lint.new(TestRequest.new))
