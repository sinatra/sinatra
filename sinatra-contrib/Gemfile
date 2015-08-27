source "https://rubygems.org" unless ENV['QUICK']
gemspec

gem 'sinatra', :github => 'sinatra/sinatra'

group :development, :test do

  platform :ruby_18 do
    gem 'libv8', '3.16.14.7'
  end

  platform :ruby_18, :jruby do
    gem 'json'
    gem 'rdoc'
  end

  platform :jruby do
    gem 'therubyrhino'
  end

  platform :jruby, :ruby do
    gem 'slim', '2.1.0'
    gem 'liquid', '2.6.1'
  end

  platform :ruby do
    gem 'execjs', '2.0.0'
    gem 'nokogiri', '1.5.10'
    gem 'redcarpet', '2.3.0'
    gem 'yajl-ruby'
    # ref is a dependency of therubyracer
    # version 2 drops support for Rubies earlier than 1.9.3
    gem 'ref', '< 2.0'
    gem 'therubyracer'
  end

  gem 'multi_json'
end

# Allows stuff like `tilt=1.2.2 bundle install` or `tilt=master ...`.
# Used by the CI.
github = "git://github.com/%s.git"
repos = { 'tilt' => github % "rtomayko/tilt", 'rack' => github % "rack/rack" }
%w[tilt rack].each do |lib|
  dep = (ENV[lib] || 'stable').sub "#{lib}-", ''
  dep = nil if dep == 'stable'
  dep = {:git => repos[lib], :branch => dep} if dep and dep !~ /(\d+\.)+\d+/
  gem lib, dep unless dep
end

