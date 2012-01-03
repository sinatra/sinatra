require 'sinatra'

configure do
  set :foo, :bar
end

get '/app_file' do
  content_type :txt
  settings.app_file
end

get '/mainonly' do
  object = Object.new
  begin
    object.send(:get, '/foo') { }
    'false'
  rescue NameError
    'true'
  end
end
