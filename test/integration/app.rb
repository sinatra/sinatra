require 'sinatra'

get '/app_file' do
  content_type :txt
  settings.app_file
end