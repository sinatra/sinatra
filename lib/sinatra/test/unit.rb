require 'test/unit'
require 'sinatra/test'

Test::Unit::TestCase.send :include, Sinatra::Test

Sinatra::Default.set(
  :env => :test,
  :run => false,
  :raise_errors => true,
  :logging => false
)
