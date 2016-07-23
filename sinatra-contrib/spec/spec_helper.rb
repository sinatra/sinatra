ENV['RACK_ENV'] = 'test'
require 'sinatra/contrib'

RSpec.configure do |config|
  config.expect_with :rspec
  config.include Sinatra::TestHelpers
end
