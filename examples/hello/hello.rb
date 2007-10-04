$LOAD_PATH.unshift File.dirname(__FILE__) + '/../../lib'
require 'sinatra'

production do
  sessions :off
end

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

# Custom 404

# get 404 do
#   'Custom 404!!!!'
# end

