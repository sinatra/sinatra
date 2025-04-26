# frozen_string_literal: true

require 'rack/protection'

module Rack
  module Protection
    ##
    # Prevented attack::   Secret leakage, third party tracking
    # Supported browsers:: Most modern browsers from 2018 onwards.  See https://caniuse.com/#search=referrer-policy for
    #                      specifics.
    # More info::          * https://www.w3.org/TR/referrer-policy/
    #                      * https://developer.mozilla.org/en-US/docs/Web/Security/Referer_header:_privacy_and_security_concerns
    #
    # Sets the {Referrer-Policy}[https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Referrer-Policy]
    # header to tell the browser to limit the Referer header.
    #
    # == Options
    # 
    # [<tt>:referrer_policy</tt>] The policy to use as a String. Default is 'strict-origin-when-cross-origin' (which,
    #                             despite being the browser's default, is still set explicitly when 
    #                             this middleware is used). Note that this option has no effect if an upstream
    #                             middleware (or your app) has set the Referrer-Policy header.
    class ReferrerPolicy < Base
      default_options referrer_policy: 'strict-origin-when-cross-origin'

      def call(env)
        status, headers, body = @app.call(env)
        headers['referrer-policy'] ||= options[:referrer_policy]
        [status, headers, body]
      end
    end
  end
end
