$LOAD_PATH.unshift '../../lib/'
require 'sinatra'

get '/' do
  body <<-HTML
  <form method="POST"><input type="text" name="name"/><input type="submit"></form>
  HTML
end

post '/' do
  body "You entered #{params[:name]}"
end

get '/erb' do
  erb :index
end

get '/test' do
  erb "Hello <%= params[:name] %>"
end
