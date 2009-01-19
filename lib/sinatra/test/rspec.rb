require 'sinatra/test'
require 'spec/interop/test'

Sinatra::Default.set(
  :environment => :test,
  :run => false,
  :raise_errors => true,
  :logging => false
)
