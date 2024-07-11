# frozen_string_literal: true

require 'logger'

module Sinatra
  module Middleware
    class Logger
      def initialize(app, level = ::Logger::INFO)
        @app, @level = app, level
      end

      def call(env)
        logger = ::Logger.new(env[Rack::RACK_ERRORS])
        logger.level = @level

        env[Rack::RACK_LOGGER] = logger
        @app.call(env)
      end
    end
  end
end
