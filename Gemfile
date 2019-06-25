# frozen_string_literal: true

# Why use bundler?
# Well, not all development dependencies install on all rubies. Moreover, `gem
# install sinatra --development` doesn't work, as it will also try to install
# development dependencies of our dependencies, and those are not conflict free.
# So, here we are, `bundle install`.
#
# If you have issues with a gem: `bundle install --without-coffee-script`.

RUBY_ENGINE = 'ruby'.freeze unless defined? RUBY_ENGINE
source 'https://rubygems.org' unless ENV['QUICK']
gemspec

gem 'minitest', '~> 5.0'
gem 'rack', git: 'https://github.com/rack/rack.git'
gem 'rack-test', '>= 0.6.2'
gem 'rake'
gem 'rubocop', '~> 0.68.1', require: false
gem 'yard'

gem 'rack-protection', path: 'rack-protection'
gem 'sinatra-contrib', path: 'sinatra-contrib'

gem 'twitter-text', '1.14.7'

if RUBY_ENGINE == 'jruby'
  gem 'nokogiri', '!= 1.5.0'
  gem 'trinidad'
end

if RUBY_ENGINE == 'ruby'
  gem 'activesupport', '~> 5.1.6'
  gem 'asciidoctor'
  gem 'bluecloth'
  gem 'builder'
  gem 'celluloid', '~> 0.16.0'
  gem 'coffee-script', '>= 2.0'
  gem 'commonmarker', '~> 0.20.0'
  gem 'creole'
  gem 'erubi'
  gem 'erubis'
  gem 'haml', '>= 3.0'
  gem 'kramdown'
  gem 'less', '~> 2.0'
  gem 'liquid'
  gem 'markaby'
  gem 'maruku'
  gem 'nokogiri'
  gem 'puma'
  gem 'rabl'
  gem 'radius'
  gem 'rdiscount'
  gem 'rdoc'
  gem 'redcarpet'
  gem 'RedCloth'
  gem 'reel-rack'
  gem 'sass'
  gem 'simplecov', require: false
  gem 'slim', '~> 2.0'
  gem 'stylus'
  gem 'therubyracer'
  gem 'thin'
  gem 'wikicloth'
  gem 'wlang', '>= 2.0.1'
  gem 'yajl-ruby'
end

if RUBY_ENGINE == 'rbx'
  gem 'erubi'
  gem 'json'
  gem 'rubysl'
  gem 'rubysl-test-unit'
end

platforms :jruby do
  gem 'json'
end
