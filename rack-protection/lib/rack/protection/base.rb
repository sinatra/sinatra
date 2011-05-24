require 'rack/protection'

module Rack
  module Protection
    class Base
      DEFAULT_OPTIONS = { :reaction => :drop_session, :logging => true }
      attr_reader :app, :options

      def self.default_options(options)
        define_method(:default_options) { super().merge(options) }
      end

      def default_options
        DEFAULT_OPTIONS
      end

      def initialize(app, options = {})
        @app, @options = app, default_options.merge(options)
      end

      def accepts?(env)
        raise NotImplementedError, "#{self.class} implementation pending"
      end

      def call(env)
        unless accepts? env
          result = send(options[:reaction], env)
          return result if Array === result and result.size = 3
        end
        app.call(env)
      end

      def warn(env, message)
        return unless options[:logging]
        l = options[:logger] || env['rack.logger'] || ::Logger.new(env['rack.errors'])
        l.warn(message)
      end

      def drop_session(env)
        env['rack.session'] = {}
      end
    end
  end
end
