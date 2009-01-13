require 'sinatra/test'
require 'spec/interop/test'

Sinatra::Default.set(
  :env => :test,
  :run => false,
  :raise_errors => true,
  :logging => false
)
