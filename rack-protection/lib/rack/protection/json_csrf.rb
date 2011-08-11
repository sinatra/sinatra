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
    class JsonCsrf < Base
      default_reaction :deny

      def call(env)
        status, headers, body = app.call(env)
        if headers['Content-Type'].to_s.split(';', 2).first =~ /^\s*application\/json\s*$/
          result = react(env) if referrer(env) != Request.new(env).host
        end
        result or [status, headers, body]
      end
    end
  end
end
