$stderr.puts "loading"
require 'sinatra'

configure do
  set :foo, :bar
end

get '/app_file' do
  content_type :txt
  settings.app_file
end

get '/ping' do
  'pong'
end

get '/stream' do
  stream do |out|
    sleep 0.1
    out << "a"
    sleep 1.2
    out << "b"
  end
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

set :out, nil
get '/async' do
  stream(:keep_open) { |o| (settings.out = o) << "hi!" }
end

get '/send' do
  settings.out << params[:msg] if params[:msg]
  settings.out.close if params[:close]
  "ok"
end

class Subclass < Sinatra::Base
  set :out, nil
  get '/subclass/async' do
    stream(:keep_open) { |o| (settings.out = o) << "hi!" }
  end

  get '/subclass/send' do
    settings.out << params[:msg] if params[:msg]
    settings.out.close if params[:close]
    "ok"
  end
end

use Subclass

$stderr.puts "starting"
