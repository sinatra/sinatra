require File.expand_path('../helper', __FILE__)
require File.expand_path('../integration_helper', __FILE__)

# These tests start a real server and talk to it over TCP.
# Every test runs with every detected server.
#
# See test/integration/app.rb for the code of the app we test against.
class IntegrationTest < Test::Unit::TestCase
  extend IntegrationHelper
  attr_accessor :server

  it('sets the app_file') { assert_equal server.app_file, server.get("/app_file") }

  it 'logs once in development mode' do
    random = "%064x" % Kernel.rand(2**256-1)
    server.get "/ping?x=#{random}"
    count = server.log.scan("GET /ping?x=#{random}").count
    server.webrick? ? assert(count > 0) : assert_equal(1, count)
  end

  it 'streams' do
    next if server.webrick?
    times, chunks = [Time.now], []
    server.get_stream do |chunk|
      next if chunk.empty?
      chunks << chunk
      times << Time.now
    end
    assert_equal ["a", "b"], chunks
    assert times[1] - times[0] < 1
    assert times[2] - times[1] > 1
  end

  it 'streams async' do
    next unless server.thin?

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
    next unless server.thin?

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

  it 'starts the correct server' do
    exp = %r{
      ==\sSinatra/#{Sinatra::VERSION}\s
      has\staken\sthe\sstage\son\s\d+\sfor\sdevelopment\s
      with\sbackup\sfrom\s#{server}
    }ix

    assert_match exp, server.log
  end

  it 'does not generate warnings' do
    assert_raise(OpenURI::HTTPError) { server.get '/' }
    server.get '/app_file'
    assert_equal [], server.warnings
  end
end