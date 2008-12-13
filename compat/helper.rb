require 'rubygems'
require 'mocha'

$:.unshift File.dirname(File.dirname(__FILE__)) + "/lib"

ENV['RACK_ENV'] ||= 'test'

require 'sinatra'
require 'sinatra/test'
require 'sinatra/test/unit'
require 'sinatra/test/spec'

class Test::Unit::TestCase
  def setup
    @app = lambda { |env| Sinatra::Application.call(env) }
  end
  include Sinatra::Test
end
