$LOAD_PATH.unshift File.dirname(__FILE__) + '/../../lib/'
require 'sinatra'

get '/test' do
  format.xml { body 'blake in xml' }
end
