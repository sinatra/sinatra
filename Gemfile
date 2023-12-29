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
rack_version = { github: 'rack/rack' } if rack_version == 'head'
gem 'rack', rack_version

puma_version = ENV['puma'].to_s
puma_version = nil if puma_version.empty? || (puma_version == 'stable')
puma_version = { github: 'puma/puma' } if puma_version == 'head'
gem 'puma', puma_version

gem 'minitest', '~> 5.0'
gem 'rack-test'
gem 'rubocop', '~> 1.32.0', require: false
gem 'yard' # used by rake doc

gem 'rack-protection', path: 'rack-protection'
gem 'sinatra-contrib', path: 'sinatra-contrib'

# traces 0.10.0 started to use Ruby 2.7 syntax without specifying required Ruby version
# https://github.com/socketry/traces/pull/8#discussion_r1237988182
# async-http 0.60.2 added traces 0.10.0 as dependency
# https://github.com/socketry/async-http/pull/124/files#r1237988899
gem 'traces', '< 0.10.0' if RUBY_VERSION >= '2.6.0' && RUBY_VERSION < '2.7.0'

gem 'asciidoctor'
gem 'builder'
gem 'childprocess'
gem 'commonmarker', '~> 0.23.4', platforms: [:ruby]
gem 'erubi'
gem 'eventmachine'
gem 'falcon', '~> 0.40', platforms: [:ruby]
gem 'haml', '~> 6'
gem 'kramdown'
gem 'liquid'
# markaby 0.9.1 introduced Ruby 2.7 syntax in https://github.com/markaby/markaby/pull/44
# and does not specify required_ruby_version
if RUBY_VERSION >= '2.6.0' && RUBY_VERSION < '2.7.0'
  gem 'markaby', '< 0.9.1'
else
  gem 'markaby'
end
gem 'nokogiri', '> 1.5.0'
gem 'pandoc-ruby', '~> 2.0.2'
gem 'rabl'
if RUBY_ENGINE == 'truffleruby'
  gem 'rdiscount', '< 2.2.7.2' # https://github.com/oracle/truffleruby/issues/3362
else
  gem 'rdiscount', platforms: [:ruby]
end
gem 'rdoc'
gem 'redcarpet', platforms: [:ruby]
gem 'sass-embedded', '~> 1.54'
gem 'simplecov', require: false
gem 'slim', '~> 4'
gem 'yajl-ruby', platforms: [:ruby]
gem 'zeitwerk'
