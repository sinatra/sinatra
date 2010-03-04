require 'sinatra/test'
require 'sinatra/test/unit'
require 'spec'
require 'spec/interop/test'

Sinatra::Test.deprecate('RSpec')

Sinatra::Application.set(
  :environment => :test,
  :run => false,
  :raise_errors => true,
  :logging => false
)
