require 'test/unit'
require File.dirname(__FILE__) + '/../sinatra/test/methods'

Test::Unit::TestCase.send(:include, Sinatra::Test::Methods)

# Sinatra.application.options.env ||= ENV['RAILS_ENV'].to_sym || :test
