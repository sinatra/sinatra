# frozen_string_literal: true

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
rack_version = nil if rack_version.empty? || (rack_version == 'stable')
rack_version = { github: 'rack/rack' } if rack_version == 'latest'
gem 'rack', rack_version

puma_version = ENV['puma'].to_s
puma_version = nil if puma_version.empty? || (puma_version == 'stable')
puma_version = { github: 'puma/puma' } if puma_version == 'latest'
gem 'puma', puma_version

gem 'minitest', '~> 5.0'
gem 'rack-test', github: 'rack/rack-test'
gem 'rubocop', '~> 1.32.0', require: false
gem 'yard'

gem 'rack-protection', path: 'rack-protection'
gem 'sinatra-contrib', path: 'sinatra-contrib'

gem 'activesupport', '~> 6.1'

gem 'asciidoctor'
gem 'builder'
gem 'commonmarker', '~> 0.23.4', platforms: [:ruby]
gem 'erubi'
gem 'eventmachine'
gem 'falcon', '~> 0.40', platforms: [:ruby]
gem 'haml', '~> 5'
gem 'kramdown'
gem 'liquid'
gem 'markaby'
gem 'nokogiri', '> 1.5.0'
gem 'pandoc-ruby', '~> 2.0.2'
gem 'rabl'
gem 'rainbows', platforms: [:mri] # uses #fork
gem 'rdiscount', platforms: [:ruby]
gem 'rdoc'
gem 'redcarpet', platforms: [:ruby]
gem 'simplecov', require: false
gem 'slim', '~> 4'
gem 'yajl-ruby', platforms: [:ruby]

gem 'json', platforms: %i[jruby mri]

gem 'jar-dependencies', '= 0.4.1', platforms: [:jruby] # Gem::LoadError with jar-dependencies 0.4.2
