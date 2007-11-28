require File.dirname(__FILE__) + '/../lib/sinatra'

require "rubygems"
require "test/spec"
require "mocha"

module Sinatra::TestHelper
  
end

Test::Unit::TestCase.send :include, Sinatra::TestHelper
  
