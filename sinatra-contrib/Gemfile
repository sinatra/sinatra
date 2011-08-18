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

