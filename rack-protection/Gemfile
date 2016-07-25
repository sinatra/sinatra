source "http://rubygems.org"
# encoding: utf-8

gem 'rake'

rack_version = ENV['rack'].to_s
rack_version = nil if rack_version.empty? or rack_version == 'stable'
rack_version = {:github => 'rack/rack'} if rack_version == 'master'
gem 'rack', rack_version

sinatra_version = ENV['sinatra'].to_s
sinatra_version = nil if sinatra_version.empty? or sinatra_version == 'stable'
sinatra_version = {:github => 'sinatra/sinatra'} if sinatra_version == 'master'
# TODO: Remove once sinatra 2.0 is released
sinatra_version = {:github => 'sinatra/sinatra'}
gem 'sinatra', sinatra_version

gemspec
