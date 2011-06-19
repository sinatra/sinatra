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
    class NoReferrer < Base
      default_reaction :deny

      def accepts?(env)
        safe?(env) or not env['HTTP_REFERER'].to_s.empty?
      end
    end
  end
end
