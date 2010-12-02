require File.dirname(__FILE__) + '/helper'

module Rack::Handler
  class Mock
    extend Test::Unit::Assertions

    def self.run(app, options={})
      assert(app < Sinatra::Base)
      assert_equal 9001, options[:Port]
      assert_equal 'foo.local', options[:Host]
      assert_equal 'foobar', options[:extra] if options[:extra]
      yield new
    end

    def stop
    end
  end

  register 'mock', 'Rack::Handler::Mock'
end

class ServerTest < Test::Unit::TestCase
  setup do
    mock_app {
      set :server, 'mock'
      set :bind, 'foo.local'
      set :port, 9001
    }
    $stdout = File.open('/dev/null', 'wb')
  end

  def teardown
    $stdout = STDOUT
  end

  it "locates the appropriate Rack handler and calls ::run" do
    @app.run!
  end

  it "sets options on the app before running" do
    @app.run! :sessions => true
    assert @app.sessions?
  end

  it "falls back on the next server handler when not found" do
    @app.run! :server => %w[foo bar mock]
  end

  it "passes on extra options to the corresponding handler" do
    @app.run! :mock => { :extra => 'foobar' }
  end
end
