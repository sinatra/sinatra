require 'sinatra/base'
require 'rack'
begin
  require 'rack/test'
rescue LoadError
  abort 'Add rack-test to your Gemfile to use this module!'
end
require 'forwardable'

module Sinatra
  Base.set :environment, :test

  # Helper methods to ease testing your Sinatra application. Partly extracted
  # from Sinatra. Testing framework agnostic.
  module TestHelpers
    # Test variant of session, which exposes a `global_env`.
    class Session < Rack::Test::Session
      def global_env
        @global_env ||= {}
      end

      private

      def default_env
        super.merge global_env
      end
    end

    include Rack::Test::Methods
    extend Forwardable
    attr_accessor :settings

    # @!group Instance Methods delegated to last_response

    # @!method body
    #
    # Body of last_response
    #
    # @see http://www.rubydoc.info/github/rack/rack/master/Rack/Response#body-instance_method
    # @return [String] body of the last response

    # @!method headers
    #
    # Headers of last_response
    #
    # @return [Hash] hash of the last response

    # @!method status
    #
    # HTTP status of last_response
    #
    # @return [Integer] HTTP status of the last response

    # @!method errors
    #
    # Errors of last_response
    #
    # @return [Array] errors of the last response
    def_delegators :last_response, :body, :headers, :status, :errors
    # @!endgroup

    # @!group Class Methods delegated to app

    # @!method configure(*envs) {|_self| ... }
    # @!scope class
    # @yieldparam _self [Sinatra::Base] the object that the method was called on
    #
    # Set configuration options for Sinatra and/or the app. Allows scoping of
    # settings for certain environments.

    # @!method set(option, value = (not_set = true), ignore_setter = false, &block)
    # @!scope class
    # Sets an option to the given value. If the value is a proc, the proc will
    # be called every time the option is accessed.
    # @raise [ArgumentError]

    # @!method enable(*opts)
    # @!scope class
    #
    # Same as calling `set :option, true` for each of the given options.

    # @!method disable(*opts)
    # @!scope class
    #
    # Same as calling `set :option, false` for each of the given options.

    # @!method use(middleware, *args, &block)
    # @!scope class
    # Use the specified Rack middleware

    # @!method helpers(*extensions, &block)
    # @!scope class
    #
    # Makes the methods defined in the block and in the Modules given in
    # `extensions` available to the handlers and templates.

    # @!method register(*extensions, &block)
    # @!scope class
    # Register an extension. Alternatively take a block from which an
    # extension will be created and registered on the fly.

    def_delegators :app, :configure, :set, :enable, :disable, :use, :helpers, :register
    # @!endgroup

    # @!group Instance Methods delegated to current_session

    # @!method env_for(uri = "", opts = {})
    #
    # Return the Rack environment used for a request to `uri`.
    #
    # @return [Hash]
    def_delegators :current_session, :env_for
    # @!endgroup

    # @!group Instance Methods delegated to rack_mock_session
    # @!method cookie_jar
    #
    # Returns a {http://www.rubydoc.info/github/rack-test/rack-test/Rack/Test/CookieJar Rack::Test::CookieJar}.
    #
    # @return [Rack::Test::CookieJar]
    def_delegators :rack_mock_session, :cookie_jar

    # @!endgroup

    # Instantiate and configure a mock Sinatra app.
    #
    # Takes a `base` app class, or defaults to Sinatra::Base, and instantiates
    # an app instance. Any given code in `block` is `class_eval`'d on this new
    # instance before the instance is returned.
    #
    # @param base [Sinatra::Base] App base class
    #
    # @return [Sinatra] Configured mocked app
    def mock_app(base = Sinatra::Base, &block)
      inner = nil
      @app  = Sinatra.new(base) do
        inner = self
        class_eval(&block)
      end
      @settings = inner
      app
    end

    # Replaces the configured app.
    #
    # @param base [Sinatra::Base] a configured app
    def app=(base)
      @app = base
    end

    alias set_app app=

    # Returns a Rack::Lint-wrapped Sinatra app.
    #
    # If no app has been configured, a new subclass of Sinatra::Base will be
    # used and stored.
    #
    # (Rack::Lint validates your application and the requests and
    # responses according to the Rack spec.)
    #
    # @return [Sinatra::Base]
    def app
      @app ||= Class.new Sinatra::Base
      Rack::Lint.new @app
    end

    unless method_defined? :options
      # Processes an OPTIONS request in the context of the current session.
      #
      # @param uri [String]
      # @param params [Hash]
      # @param env [Hash]
      def options(uri, params = {}, env = {}, &block)
        env = env_for(uri, env.merge(:method => "OPTIONS", :params => params))
        current_session.send(:process_request, uri, env, &block)
      end
    end

    unless method_defined? :patch
      # Processes a PATCH request in the context of the current session.
      #
      # @param uri [String]
      # @param params [Hash]
      # @param env [Hash]
      def patch(uri, params = {}, env = {}, &block)
        env = env_for(uri, env.merge(:method => "PATCH", :params => params))
        current_session.send(:process_request, uri, env, &block)
      end
    end

    # @return [Boolean]
    def last_request?
      last_request
      true
    rescue Rack::Test::Error
      false
    end

    # @raise [Rack::Test:Error] If sessions are not enabled for app
    # @return [Hash] Session of last request, or the empty Hash
    def session
      return {} unless last_request?
      raise Rack::Test::Error, "session not enabled for app" unless last_env["rack.session"] or app.session?
      last_request.session
    end

    # @return The env of the last request
    def last_env
      last_request.env
    end

    def build_rack_test_session(name) # :nodoc:
      Session.new rack_mock_session(name)
    end
  end
end
