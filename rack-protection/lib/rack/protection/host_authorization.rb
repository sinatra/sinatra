# frozen_string_literal: true

require 'ipaddr'
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
      PORT_REGEXP = /:\d+\z/.freeze
      default_reaction :deny
      default_options allow_if: nil,
                      message: "Host not permitted"

      def initialize(*)
        super
        @all_permitted_hosts = Array(options[:permitted_hosts])
        @permitted_hosts = @all_permitted_hosts
          .select { |host| host.is_a?(String) }
          .map(&:downcase)
        @ip_hosts = @all_permitted_hosts.select { |host| host.is_a?(IPAddr) }
      end

      def accepts?(env)
        return true if options[:allow_if]&.call(env)
        return true if @all_permitted_hosts.empty?

        request = Request.new(env)
        origin_host = extract_host(request.host_authority)
        forwarded_host = extract_host(request.forwarded_authority)

        if host_permitted?(origin_host)
          if forwarded_host.nil?
            true
          else
            host_permitted?(forwarded_host)
          end
        else
          false
        end
      end

      private

      def extract_host(authority)
        authority&.split(PORT_REGEXP)&.first&.downcase
      end

      def host_permitted?(host)
        return true if @permitted_hosts.include?(host)

        ip_match?(host)
      end

      def ip_match?(host)
        @ip_hosts.any? { |ip_host| ip_host.include?(host) }
      rescue IPAddr::InvalidAddressError
        false
      end
    end
  end
end
