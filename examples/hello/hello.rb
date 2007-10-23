$LOAD_PATH.unshift File.dirname(__FILE__) + '/../../lib'
require 'sinatra'

config_for(:production) do

  get 404 do
    "Not sure what you're looking for .. try something else."
  end
end

sessions :off
  
get '/' do
  "Hello World!"
end

get '/erb.xml' do
  header 'Content-Type' => 'application/xml'
  '<this_is_xml/>'
end

get '/erb' do
  erb :hello
end

get '/erb2' do
  erb 'Hello <%= params[:name].capitalize || "World" %> 2!'
end
