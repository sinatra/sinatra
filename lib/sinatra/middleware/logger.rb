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

    class NullLogger
      def initialize(app)
        @app = app
      end

      def call(env)
        env[Rack::RACK_LOGGER] = self
        @app.call(env)
      end

      def info(progname = nil, &block); end
      def debug(progname = nil, &block); end
      def warn(progname = nil, &block); end
      def error(progname = nil, &block); end
      def fatal(progname = nil, &block); end
      def unknown(progname = nil, &block); end
      def info? ;  end
      def debug? ; end
      def warn? ;  end
      def error? ; end
      def fatal? ; end
      def debug! ; end
      def error! ; end
      def fatal! ; end
      def info! ; end
      def warn! ; end
      def level ; end
      def progname ; end
      def datetime_format ; end
      def formatter ; end
      def sev_threshold ; end
      def level=(level); end
      def progname=(progname); end
      def datetime_format=(datetime_format); end
      def formatter=(formatter); end
      def sev_threshold=(sev_threshold); end
      def close ; end
      def add(severity, message = nil, progname = nil, &block); end
      def log(severity, message = nil, progname = nil, &block); end
      def <<(msg); end
      def reopen(logdev = nil); end
    end
  end
end
