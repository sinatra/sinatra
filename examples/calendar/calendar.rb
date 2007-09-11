$LOAD_PATH.unshift File.dirname(__FILE__) + '/../../lib/'
require 'sinatra'

get '/' do
  html {p "here, b"}
  p "hi"
end

get 'index' do
  html {body "in here!"}
  body do 
    "pancakes"
  end
end

get 'favicon' do
end
