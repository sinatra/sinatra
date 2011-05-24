require 'rack/protection'

module Rack
  module Protection
    ##
    # Sets X-XSS-Protection header to tell the browser to block attacks.
    #
    # Prevented attack::   Non-permanent XSS
    # Supported browsers:: Internet Explorer >= 8
    #
    # Options:
    # xss_mode:: How the browser should prevent the attack (default: `:block`)
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
