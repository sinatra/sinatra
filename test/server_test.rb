require_relative 'test_helper'
require 'stringio'

module Rackup::Handler
  class Mock
    extend Minitest::Assertions
    # Allow assertions in request context
    def self.assertions
      @assertions ||= 0
    end

    def self.assertions= assertions
      @assertions = assertions
    end

    def self.run(app, options={})
      assert(app < Sinatra::Base)
      assert_equal 9001, options[:Port]
      assert_equal 'foo.local', options[:Host]
      yield new
    end

    def stop
    end
  end

  register :mock, Mock
end

class ServerTest < Minitest::Test
  setup do
    mock_app do
      set :server, 'mock'
      set :bind, 'foo.local'
      set :port, 9001
    end
    $stderr = StringIO.new
  end

  def teardown
    $stderr = STDERR
  end

  it "locates the appropriate Rack handler and calls ::run" do
    @app.run!
  end

  context "event hooks" do
    dummy_class = Class.new do
      def self.start_hook; end
      def self.stop_hook; end
    end

    it "runs the provided code when the server starts" do
      @app.on_start do
        dummy_class.start_hook
      end
      mock = Minitest::Mock.new
      mock.expect(:call, nil)

      dummy_class.stub(:start_hook, mock) do
        @app.run!
      end

      assert_mock mock
    end

    it "runs the provided code when the server stops" do
      @app.on_stop do
        dummy_class.stop_hook
      end
      mock = Minitest::Mock.new
      mock.expect(:call, nil)

      dummy_class.stub(:stop_hook, mock) do
        @app.run!
        @app.quit!
      end

      assert_mock mock
    end
  end

  it "sets options on the app before running" do
    @app.run! :sessions => true
    assert @app.sessions?
  end

  it "falls back on the next server handler when not found" do
    @app.run! :server => %w[foo bar mock]
  end

  it "initializes Rack middleware immediately on server run" do
    class MyMiddleware
      @@initialized = false
      def initialize(app)
        @@initialized = true
      end
      def self.initialized
        @@initialized
      end
      def call(env)
      end
    end

    @app.use MyMiddleware
    assert_equal(MyMiddleware.initialized, false)
    @app.run!
    assert_equal(MyMiddleware.initialized, true)
  end

  describe "Quiet mode" do
    it "sends data to stderr when server starts and stops" do
      @app.run!
      assert_match(/\=\= Sinatra/, $stderr.string)
    end

    context "when quiet mode is activated" do
      it "does not generate Sinatra start and stop messages" do
        @app.run! quiet: true
        refute_match(/\=\= Sinatra/, $stderr.string)
      end
    end
  end
end
