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

rack_version = ENV['rack'].to_s
rack_version = nil if rack_version.empty? or rack_version == 'stable'
rack_version = {:github => 'rack/rack'} if rack_version == 'master'
gem 'rack', rack_version

gem 'rack-test', '>= 0.6.2', '< 2'
gem "minitest", "~> 5.0"
gem 'yard'

gem "rack-protection", path: "rack-protection"
gem "sinatra-contrib", path: "sinatra-contrib"


gem "activesupport", "~> 6.1"

gem 'redcarpet', platforms: [ :ruby ]
gem 'rdiscount', platforms: [ :ruby ]
gem 'puma'
gem 'falcon', '~> 0.40', platforms: [ :ruby ]
gem 'yajl-ruby', platforms: [ :ruby ]
gem 'nokogiri', '> 1.5.0'
gem 'rainbows', platforms: [ :mri ] # uses #fork
gem 'eventmachine'
gem 'slim', '~> 4'
gem 'rdoc'
gem 'kramdown'
gem 'markaby'
gem 'asciidoctor'
gem 'liquid'
gem 'rabl'
gem 'builder'
gem 'erubi'
gem 'haml', '~> 5'
gem 'commonmarker', '~> 0.20.0', platforms: [ :ruby ]
gem 'pandoc-ruby', '~> 2.0.2'
gem 'simplecov', require: false

gem 'json', platforms: [ :jruby, :mri ]
