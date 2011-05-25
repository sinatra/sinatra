require 'rack/protection'

module Rack
  module Protection
    ##
    # Prevented attack::   CSRF
    # Supported browsers:: all
    # More infos::         http://en.wikipedia.org/wiki/Cross-site_request_forgery
    #
    # Only accepts unsafe HTTP requests if the Referer [sic] header is set.
    # Combine with RemoteRefferer for optimal security.
    #
    # This middleware is not used when using the Rack::Protection collection,
    # since it renders web services unusable.
    #
    # Not Yet Implemented!
    class NoReferrer < Base
      default_reaction :deny

      def accepts?(env)
        safe?(env) or (env['HTTP_REFERER'] and not env['HTTP_REFERER'].empty?)
      end
    end
  end
end
