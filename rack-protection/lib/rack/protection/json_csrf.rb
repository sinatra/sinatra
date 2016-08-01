require 'rack/protection'

module Rack
  module Protection
    ##
    # Prevented attack::   CSRF
    # Supported browsers:: all
    # More infos::         http://flask.pocoo.org/docs/security/#json-security
    #
    # JSON GET APIs are vulnerable to being embedded as JavaScript while the
    # Array prototype has been patched to track data. Checks the referrer
    # even on GET requests if the content type is JSON.
    #
    # Uses HttpOrigin to determine if requests are safe, please refer to the
    # documentation for more.
    class JsonCsrf < Base
      alias react deny

      def call(env)
        request               = Request.new(env)
        status, headers, body = app.call(env)

        if has_vector?(request, headers)
          warn env, "attack prevented by #{self.class}"

          react_and_close(env, body) or [status, headers, body]
        else
          [status, headers, body]
        end
      end

      def has_vector?(request, headers)
        return false if request.xhr?
        return false unless headers['Content-Type'].to_s.split(';', 2).first =~ /^\s*application\/json\s*$/
        origin(request.env).nil? and referrer(request.env) != request.host
      end

      def react_and_close(env, body)
        reaction = react(env)

        close_body(body) if reaction

        reaction
      end

      def close_body(body)
        body.close if body.respond_to?(:close)
      end
    end
  end
end
