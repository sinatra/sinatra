$LOAD_PATH.unshift File.dirname(__FILE__) + '/../../lib/'
require 'sinatra'

get '/' do
  format.html {p "here, b"}
  p "hi"
end
