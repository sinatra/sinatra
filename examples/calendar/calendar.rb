$LOAD_PATH.unshift File.dirname(__FILE__) + '/../../lib/'
require 'sinatra'

get '/' do
  format.html { body 'blake' }
  format.xml { body 'test' }
end
