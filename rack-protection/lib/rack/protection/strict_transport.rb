# frozen_string_literal: true

require 'rack/protection'

module Rack
  module Protection
    ##
    # Prevented attack::   Protects against against protocol downgrade attacks and cookie hijacking.
    # Supported browsers:: All modern browsers. See https://caniuse.com/stricttransportsecurity
    # More info::          https://en.wikipedia.org/wiki/HTTP_Strict_Transport_Security
    #
    # Sets the {Strict-Transport-Security}[https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Strict-Transport-Security]
    # http header. This headers tells the browser that HTTP requests will be upgraded to HTTPS.
    # It also prevents HTTPS click through prompts on browsers.
    #
    # Note that if an upstream middleware sets the Strict-Transport-Security header, this middleware will not overwrite
    # it and thus have no effect.
    #
    # == Options
    #
    # [<tt>:max_age</tt>] Time, in seconds, that the browser should remember the requirement to use HTTPS. Default is
    #                     one year.
    # [<tt>:include_subdomains</tt>] If true, all present and future subdomains should also use HTTPS. Default is false.
    # [<tt>:preload</tt>] Allow this domain to be included in browsers HSTS preload list. Default is false.
    #                     See https://hstspreload.org/
    class StrictTransport < Base
      default_options max_age: 31_536_000, include_subdomains: false, preload: false

      def strict_transport
        @strict_transport ||= begin
          strict_transport = "max-age=#{options[:max_age]}"
          strict_transport += '; includeSubDomains' if options[:include_subdomains]
          strict_transport += '; preload' if options[:preload]
          strict_transport.to_str
        end
      end

      def call(env)
        status, headers, body = @app.call(env)
        headers['strict-transport-security'] ||= strict_transport
        [status, headers, body]
      end
    end
  end
end
