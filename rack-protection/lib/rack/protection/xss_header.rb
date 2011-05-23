module Rack
  module Protection
    class XSSHeader
      HEADERS = {
        'X-XSS-Protection' => '1; mode=block',
        'X-Frame-Options'  => 'sameorigin'
      }

      def initialize(app, options)
        @app     = app
        @headers = HEADERS.merge(options[:xss_headers] || {})
        @headers.delete_if { |k,v| !v }
      end

      def call(env)
        status, headers, body = @app.call(env)
        [status, @headers.merge(headers), body]
      end
    end
  end
end
