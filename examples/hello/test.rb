$LOAD_PATH.unshift File.dirname(__FILE__) + '/../../lib/'
require 'sinatra'

get '/test/:name' do
  params[:name]
end
