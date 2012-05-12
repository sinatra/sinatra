require 'rack/protection'

module Rack
  module Protection
    ##
    # Prevented attack::   CSRF
    # Supported browsers:: Google Chrome 2, Safari 4 and later
    # More infos::         http://en.wikipedia.org/wiki/Cross-site_request_forgery
    #                      http://tools.ietf.org/html/draft-abarth-origin
    #
    # Does not accept unsafe HTTP requests when value of Origin HTTP request header
    # does not match default or whitelisted URIs.
    class HttpOrigin < Base
      default_reaction :deny

      def accepts?(env)
        # only for unsafe request methods
        safe?(env) and return true
        # ignore if origin is not set
        origin = env['HTTP_ORIGIN'] or return true

        # check base url
        Request.new(env).base_url == origin and return true

        # check whitelist
        options[:origin_whitelist] or return false
        options[:origin_whitelist].include?(origin)
      end

    end
  end
end
