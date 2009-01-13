require 'sinatra/test'
require 'test/unit'

Test::Unit::TestCase.send :include, Sinatra::Test

Sinatra::Default.set(
  :env => :test,
  :run => false,
  :raise_errors => true,
  :logging => false
)
