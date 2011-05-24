require 'rack/protection'

module Rack
  module Protection
    ##
    # Prevented attack::   CSRF
    # Supported browsers:: all
    # More infos::         http://en.wikipedia.org/wiki/Cross-site_request_forgery
    #
    # Only accepts submitted forms if a given access token matches the token
    # included in the session. Does not expect such a token from Ajax request.
    #
    # This middleware is not used when using the Rack::Protection collection,
    # since it might be a security issue, depending on your application
    #
    # Compatible with Rails and rack-csrf.
    #
    # Not Yet Implemented!
    class FormToken < AuthenticityToken
    end
  end
end
