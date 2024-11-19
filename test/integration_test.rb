require_relative 'test_helper'
require File.expand_path('integration_helper', __dir__)

# These tests start a real server and talk to it over TCP.
# Every test runs with every detected server.
#
# See test/integration/app.rb for the code of the app we test against.
class IntegrationTest < Minitest::Test
  extend IntegrationHelper
  attr_accessor :server

  it('sets the app_file') { assert_equal server.app_file, server.get("/app_file") }
  it('only extends main') { assert_equal "true", server.get("/mainonly") }

  it 'logs once in development mode' do
    next if server.puma? or server.falcon? or RUBY_ENGINE == 'jruby'
    random = "%064x" % Kernel.rand(2**256-1)
    server.get "/ping?x=#{random}"
    count = server.log.scan("GET /ping?x=#{random}").count
    if server.net_http_server?
      assert_equal 0, count
    elsif server.webrick?
      assert(count > 0)
    else
      assert_equal(1, count)
    end
  end

  it 'streams' do
    next if server.webrick? or server.trinidad?
    times, chunks = [Process.clock_gettime(Process::CLOCK_MONOTONIC)], []
    server.get_stream do |chunk|
      next if chunk.empty?
      chunks << chunk
      times << Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
    assert_equal ["a", "b"], chunks
    int1 = (times[1] - times[0]).round 2
    int2 = (times[2] - times[1]).round 2
    assert_operator 1, :>, int1
    assert_operator 1, :<, int2
  end

  it 'starts the correct server' do
    exp = %r{
      ==\sSinatra\s\(v#{Sinatra::VERSION}\)\s
      has\staken\sthe\sstage\son\s\d+\sfor\sdevelopment\s
      with\sbackup\sfrom\s#{server}
    }ix

    # because Net HTTP Server logs to $stderr by default
    assert_match exp, server.log unless server.net_http_server?
  end

  it 'does not generate warnings' do
    assert_raises(OpenURI::HTTPError) { server.get '/' }
    server.get '/app_file'
    assert_equal [], server.warnings
  end

  it 'sets the Content-Length response header when sending files' do
    response = server.get_response '/send_file'
    assert response['Content-Length']
  end

  it "doesn't ignore Content-Length header when streaming" do
    response = server.get_response '/streaming'
    assert_equal '46', response['Content-Length']
  end
end
