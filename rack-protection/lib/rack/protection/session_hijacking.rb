require 'rack/protection'

module Rack
  module Protection
    ##
    # Prevented attack::   Session Hijacking
    # Supported browsers:: all
    # More infos::         http://en.wikipedia.org/wiki/Session_hijacking
    #
    # Tracks request properties like the user agent in the session and empties
    # the session if those properties change. This essentially prevents attacks
    # from Firesheep. Since all headers taken into consideration might be
    # spoofed, too, this will not prevent all hijacking attempts.
    #
    # Not Yet Implemented!
    class SessionHijacking < Base
    end
  end
end
