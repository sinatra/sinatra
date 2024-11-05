# frozen_string_literal: true

require 'rack/protection'

module Rack
  module Protection
    ##
    # Prevented attack::   DNS rebinding and other Host header attacks
    # Supported browsers:: all
    # More infos::         https://en.wikipedia.org/wiki/DNS_rebinding
    #                      https://portswigger.net/web-security/host-header
    #
    # Blocks HTTP requests with an unrecognized hostname in any of the following
    # HTTP headers: Host, X-Forwarded-Host, Forwarded
    #
    # If you want to permit a specific hostname, you can pass in as the `:permitted_hosts` option:
    #
    #     use Rack::Protection::HostAuthorization, permitted_hosts: ["www.example.org", "sinatrarb.com"]
    #
    # The `:allow_if` option can also be set to a proc to use custom allow/deny logic.
    class HostAuthorization < Base
      default_reaction :deny
      default_options allow_if: nil,
                      message: "Host not permitted"

      def self.forwarded?(request)
        request.get_header(Request::HTTP_X_FORWARDED_HOST)
      end

      def self.host_from(request:)
        if forwarded?(request) || (request.port != (request.ssl? ? 443 : 80))
          request.host_with_port
        else
          request.host
        end
      end

      def initialize(*)
        super
        @permitted_hosts = Array(options[:permitted_hosts]).map(&:downcase)
      end

      def accepts?(env)
        return true if options[:allow_if]&.call(env)
        return true if @permitted_hosts.empty?

        request = Request.new(env)
        origin_host = self.class.host_from(request: request)

        @permitted_hosts.include?(origin_host.downcase)
      end
    end
  end
end
