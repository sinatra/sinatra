require 'rack/protection'

module Rack
  module Protection
    ##
    # Prevented attack::   Session Hijacking
    # Supported browsers:: all
    # More infos::         http://en.wikipedia.org/wiki/Session_hijacking
    #
    # Tracks request properties like the user agent in the session and empties
    # the session if those properties change.
    #
    # Not Yet Implemented!
    class SessionHijacking < Base
    end
  end
end
