require 'sinatra/base'
require 'rack/test'
require 'rack'
require 'forwardable'

module Sinatra
  Base.set :environment, :test

  module TestHelpers
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

    def_delegators :last_response, :body, :headers, :status, :errors
    def_delegators :app, :configure, :set, :enable, :disable, :use, :helpers, :register
    def_delegators :current_session, :env_for
    def_delegators :rack_mock_session, :cookie_jar

    def mock_app(base = Sinatra::Base, &block)
      inner = nil
      @app  = Sinatra.new(base) do
        inner = self
        class_eval(&block)
      end
      @settings = inner
      app
    end

    def app=(base)
      @app = base
    end

    alias set_app app=

    def app
      @app ||= Class.new Sinatra::Base
      Rack::Lint.new @app
    end

    unless method_defined? :options
      def options(uri, params = {}, env = {}, &block)
        env = env_for(uri, env.merge(:method => "OPTIONS", :params => params))
        current_session.send(:process_request, uri, env, &block)
      end
    end

    unless method_defined? :patch
      def patch(uri, params = {}, env = {}, &block)
        env = env_for(uri, env.merge(:method => "PATCH", :params => params))
        current_session.send(:process_request, uri, env, &block)
      end
    end

    def last_request?
      last_request
      true
    rescue Rack::Test::Error
      false
    end

    def session
      return {} unless last_request?
      raise Rack::Test::Error, "session not enabled for app" unless last_env["rack.session"] or app.session?
      last_request.session
    end

    def last_env
      last_request.env
    end

    def build_rack_test_session(name) # :nodoc:
      Session.new rack_mock_session(name)
    end
  end
end
