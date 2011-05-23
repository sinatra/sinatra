require 'rack/protection'

module Rack
  module Protection
    class XSSHeader < Base
      default_options :xss_mode => :block

      def header
        { 'X-XSS-Protection' => "1; mode=#{options[:xss_mode]}" }
      end

      def call(env)
        status, headers, body = @app.call(env)
        [status, header.merge(headers), body]
      end
    end
  end
end
