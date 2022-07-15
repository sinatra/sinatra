# Why use bundler?
# Well, not all development dependencies install on all rubies. Moreover, `gem
# install sinatra --development` doesn't work, as it will also try to install
# development dependencies of our dependencies, and those are not conflict free.
# So, here we are, `bundle install`.
#
# If you have issues with a gem: `bundle install --without-coffee-script`.

source 'https://rubygems.org'
gemspec

gem 'rake'
gem 'rack'
gem 'rack-test', '>= 0.6.2', '< 2'
gem "minitest", "~> 5.0"
gem 'yard'

gem "rack-protection", path: "rack-protection"
gem "sinatra-contrib", path: "sinatra-contrib"

gem "twitter-text", "1.14.7"


gem "activesupport", "~> 6.1"

gem 'redcarpet', platforms: [ :ruby ]
gem 'rdiscount', platforms: [ :ruby ]
gem 'puma'
gem 'yajl-ruby', platforms: [ :ruby ]
gem 'nokogiri', '> 1.5.0'
gem 'rainbows', platforms: [ :ruby ]
gem 'eventmachine'
gem 'slim', '~> 4'
gem 'coffee-script', '>= 2.0'
gem 'rdoc'
gem 'kramdown'
gem 'creole'
gem 'wikicloth'
gem 'markaby'
gem 'radius'
gem 'asciidoctor'
gem 'liquid'
gem 'rabl'
gem 'builder'
gem 'erubi'
gem 'haml', '~> 5'
gem 'celluloid', '~> 0.16.0'
gem 'commonmarker', '~> 0.20.0', platforms: [ :ruby ]
gem 'pandoc-ruby', '~> 2.0.2'
gem 'simplecov', require: false

gem 'json', platforms: [ :jruby, :mri ]
