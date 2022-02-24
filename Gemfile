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
gem 'rack-test', '>= 0.6.2'
gem "minitest", "~> 5.0"
gem 'yard'

gem "rack-protection", path: "rack-protection"
gem "sinatra-contrib", path: "sinatra-contrib"

gem "twitter-text", "1.14.7"


gem "activesupport", "~> 5.1.6", platforms: [ :jruby, :mri ]

gem 'redcarpet', platforms: [ :mri ]
gem 'wlang', '>= 3.0.1'
gem 'bluecloth', platforms: [ :mri ]
gem 'rdiscount', platforms: [ :mri ]
gem 'RedCloth', platforms: [ :mri ]
gem 'puma', platforms: [ :jruby, :mri ]
gem 'yajl-ruby', platforms: [ :mri ]
gem 'nokogiri', '> 1.5.0', platforms: [ :jruby, :mri ]
gem 'rainbows', platforms: [ :mri ]
gem 'eventmachine'
gem 'slim', '~> 2.0'
gem 'coffee-script', '>= 2.0'
gem 'rdoc'
gem 'kramdown'
gem 'maruku'
gem 'creole'
gem 'wikicloth'
gem 'markaby'
gem 'radius'
gem 'asciidoctor'
gem 'liquid'
gem 'rabl'
gem 'builder'
gem 'erubi'
gem 'erubis'
gem 'haml', '>= 3.0'
gem 'sass'
gem 'celluloid', '~> 0.16.0'
gem 'commonmarker', '~> 0.20.0', platforms: [ :mri ]
gem 'pandoc-ruby', '~> 2.0.2'
gem 'simplecov', require: false

gem 'json', platforms: [ :jruby, :mri ]
