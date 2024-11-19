# frozen_string_literal: true

source 'https://rubygems.org'
gemspec

gem 'rake'

rack_version = ENV['rack'].to_s
rack_version = nil if rack_version.empty? || (rack_version == 'stable')
rack_version = { github: 'rack/rack' } if rack_version == 'head'
gem 'rack', rack_version

rack_session_version = ENV['rack_session'].to_s
rack_session_version = nil if rack_session_version.empty? || (rack_session_version == 'stable')
rack_session_version = { github: 'rack/rack-session' } if rack_session_version == 'head'
gem 'rack-session', rack_session_version

gem 'rackup'

puma_version = ENV['puma'].to_s
puma_version = nil if puma_version.empty? || (puma_version == 'stable')
puma_version = { github: 'puma/puma' } if puma_version == 'head'
gem 'puma', puma_version

zeitwerk_version = ENV['zeitwerk'].to_s
zeitwerk_version = nil if zeitwerk_version.empty? || (zeitwerk_version == 'stable')
gem 'zeitwerk', zeitwerk_version

gem 'minitest', '~> 5.0'
gem 'rack-test'
gem 'rubocop', '~> 1.32.0', require: false
gem 'yard' # used by rake doc

gem 'rack-protection', path: 'rack-protection'
gem 'sinatra-contrib', path: 'sinatra-contrib'

gem 'asciidoctor'
gem 'builder'
gem 'childprocess', '>= 5'
gem 'commonmarker', '~> 0.23.4', platforms: [:ruby]
gem 'erubi'
gem 'eventmachine'
gem 'falcon', '~> 0.40', platforms: [:ruby]
gem 'haml', '~> 6'
gem 'kramdown'
gem 'liquid'
gem 'markaby'
gem 'nokogiri', '> 1.5.0'
gem 'ostruct'
gem 'pandoc-ruby', '~> 2.0.2'
gem 'rabl'
gem 'rdiscount', platforms: [:ruby]
gem 'rdoc'
gem 'redcarpet', platforms: [:ruby]
gem 'simplecov', require: false
gem 'slim', '~> 5'
gem 'yajl-ruby', platforms: [:ruby]
gem 'webrick'

# sass-embedded depends on google-protobuf
# which fails to be installed on JRuby and TruffleRuby under aarch64
# https://github.com/jruby/jruby/issues/8062
# https://github.com/protocolbuffers/protobuf/issues/11935
java    = %w(jruby truffleruby).include?(RUBY_ENGINE)
aarch64 = RbConfig::CONFIG["target_cpu"] == 'aarch64'
gem 'sass-embedded', '~> 1.54' unless java && aarch64
