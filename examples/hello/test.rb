$LOAD_PATH.unshift File.dirname(__FILE__) + '/../../lib/'
require 'sinatra'

get '/test' do
  'test'
end
