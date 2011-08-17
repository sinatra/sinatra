source "http://rubygems.org" unless ENV['QUICK']
gemspec

gem 'sinatra', :git => 'git://github.com/sinatra/sinatra'

group :development, :test do
  platform :ruby_18, :jruby do
    gem 'json'
  end

  platform :ruby do
    gem 'yajl-ruby'
  end
end
