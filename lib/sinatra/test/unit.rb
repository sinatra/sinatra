require 'test/unit'
require File.dirname(__FILE__) + '/methods'

Test::Unit::TestCase.send(:include, Sinatra::Test::Methods)

Sinatra::Application.default_options.merge!(
  :env => :test,
  :run => false,
  :raise_errors => true,
  :logging => false
)

Sinatra.application = nil
