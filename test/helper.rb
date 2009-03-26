begin
  require 'rack'
rescue LoadError
  require 'rubygems'
  require 'rack'
end

testdir = File.dirname(__FILE__)
$LOAD_PATH.unshift testdir unless $LOAD_PATH.include?(testdir)

libdir = File.dirname(File.dirname(__FILE__)) + '/lib'
$LOAD_PATH.unshift libdir unless $LOAD_PATH.include?(libdir)

require 'contest'
require 'sinatra/test'

class Sinatra::Base
  # Allow assertions in request context
  include Test::Unit::Assertions
end

Sinatra::Base.set :environment, :test

class Test::Unit::TestCase
  include Sinatra::Test

  class << self
    alias_method :it, :test
  end

  # Sets up a Sinatra::Base subclass defined with the block
  # given. Used in setup or individual spec methods to establish
  # the application.
  def mock_app(base=Sinatra::Base, &block)
    @app = Sinatra.new(base, &block)
  end
end

# Do not output warnings for the duration of the block.
def silence_warnings
  $VERBOSE, v = nil, $VERBOSE
  yield
ensure
  $VERBOSE = v
end
