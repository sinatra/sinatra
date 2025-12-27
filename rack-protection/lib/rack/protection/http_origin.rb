# frozen_string_literal: true

require 'rack/protection'

module Rack
  module Protection
    ##
    # Prevented attack::   CSRF
    # Supported browsers:: Google Chrome 4, Safari 3.1, Firefox 70, Edge 70 and later.
    #                      See https://caniuse.com/mdn-http_headers_origin, for a complete list.
    # More infos::         * http://en.wikipedia.org/wiki/Cross-site_request_forgery
    #                      * http://tools.ietf.org/html/draft-abarth-origin
    #                      * https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Origin
    #
    # Rejects any {unsafe request}[https://httpwg.org/specs/rfc9110.html#safe.methods]
    # whose Origin HTTP header does match one of the origins given to <tt>:permitted_origins</tt>.
    # Note that if the Origin is the same as the request host, the request is always allowed.
    # Similarly, if there is not Origin header for an unsafe request, it is always denied.
    #
    # == Options
    #
    # [<tt>:permitted_origins</tt>] A String or Array of Strings representing the *additional* allowed origins for
    #                               an unsafe request. The values must be exact matches for the 
    #                               value provided in the Origin header.  Generally speaking, this means
    #                               that you should include the scheme, and include the port *only* if it 
    #                               is not the default port for the scheme (80 for http and 443 for https).
    #
    # [<tt>:allow_if</tt>] A Proc to be used for custom logic, superceding the values in <tt>:permitted_origins</tt>.
    #                      By default, this is <tt>nil</tt>, meaning that <tt>:permitted_origins</tt> control
    #                      the behavior. Note that if the request's origin is the same as the Origin header,
    #                      this Proc is not evaluated and the request is allowed.  Further note that if there is no
    #                      Origin header, this Proc is not evaluated and the request is denied.
    #
    # [Rack::Protection::Base options] options supported by Rack::Protection::Base may affect this middleware.
    #
    #
    # == Example: Including your local dev environment
    #
    #     use Rack::Protection, permitted_origins: ["http://localhost:3000", "http://127.0.0.1:3000"]
    #
    class HttpOrigin < Base
      DEFAULT_PORTS = { 'http' => 80, 'https' => 443, 'coffee' => 80 }
      default_reaction :deny
      default_options allow_if: nil

      def base_url(env)
        request = Rack::Request.new(env)
        port = ":#{request.port}" unless request.port == DEFAULT_PORTS[request.scheme]
        "#{request.scheme}://#{request.host}#{port}"
      end

      def accepts?(env)
        return true if safe? env
        return true unless (origin = env['HTTP_ORIGIN'])
        return true if base_url(env) == origin
        return true if options[:allow_if]&.call(env)

        permitted_origins = options[:permitted_origins]
        Array(permitted_origins).include? origin
      end
    end
  end
end
