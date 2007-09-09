$LOAD_PATH.unshift File.dirname(__FILE__) + '/../../lib/'
require 'sinatra'

after_attend :log_fun_stuff

helpers do
  def log_fun_stuff
    logger.debug "THIS IS COOL!"
  end
end

get '/' do
  body <<-HTML
  <form method="POST"><input type="text" name="name"/><input type="submit"></form>
  HTML
end

get '/hello' do
  "Hello World!"
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
