require File.dirname(__FILE__) + '/helper'

class Rack::Handler::Mock
  extend Test::Unit::Assertions

  def self.run(app, options={})
    assert(app < Sinatra::Base)
    assert_equal 9001, options[:Port]
    assert_equal 'foo.local', options[:Host]
    yield new
  end

  def stop
  end
end

describe 'Sinatra::Base.run!' do
  before do
    mock_app {
      set :server, 'mock'
      set :host, 'foo.local'
      set :port, 9001
    }
    $stdout = File.open('/dev/null', 'wb')
  end

  after { $stdout = STDOUT }

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
end
