require_relative 'test_helper'
require File.expand_path('integration_async_helper', __dir__)

# These tests are like integration_test, but they test asynchronous streaming.
class IntegrationAsyncTest < Minitest::Test
  extend IntegrationAsyncHelper
  attr_accessor :server

  it 'streams async' do
    Timeout.timeout(3) do
      chunks = []
      server.get_stream '/async' do |chunk|
        next if chunk.empty?
        chunks << chunk
        case chunk
        when "hi!"   then server.get "/send?msg=hello"
        when "hello" then server.get "/send?close=1"
        end
      end

      assert_equal ['hi!', 'hello'], chunks
    end
  end

  it 'streams async from subclass' do
    Timeout.timeout(3) do
      chunks = []
      server.get_stream '/subclass/async' do |chunk|
        next if chunk.empty?
        chunks << chunk
        case chunk
        when "hi!"   then server.get "/subclass/send?msg=hello"
        when "hello" then server.get "/subclass/send?close=1"
        end
      end

      assert_equal ['hi!', 'hello'], chunks
    end
  end
end
