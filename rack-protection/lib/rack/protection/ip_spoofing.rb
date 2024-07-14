# frozen_string_literal: true

require 'rack/protection'

module Rack
  module Protection
    ##
    # Prevented attack::   IP spoofing
    # Supported browsers:: all
    # More infos::         http://blog.c22.cc/2011/04/22/surveymonkey-ip-spoofing/
    #
    # Detect (some) IP spoofing attacks.
    class IPSpoofing < Base
      default_reaction :deny

      def accepts?(env)
        return true unless env.include?('HTTP_X_FORWARDED_FOR') || env.include?('HTTP_FORWARDED')

        ips = if env['HTTP_FORWARDED']
          parse_forwarded(env['HTTP_FORWARDED'])
        else
          env['HTTP_X_FORWARDED_FOR'].split(',').map(&:strip)
        end

        return false if env.include?('HTTP_CLIENT_IP') && (!ips.include? env['HTTP_CLIENT_IP'])
        return false if env.include?('HTTP_X_REAL_IP') && (!ips.include? env['HTTP_X_REAL_IP'])

        true
      end

      private

      def parse_forwarded(forwarded_header)
        return nil unless forwarded_header

        ips = []

        forwarded_header.to_s.split(/\s*;\s*/).each do |field|
          field.split(/\s*,\s*/).each do |key|
            # Use a regex to match and capture 'for' and 'by' fields along with their IP addresses
            if match = key.match(/\A\s*(by|for)\s*=\s*"?\[?([^\]]+)\]?"?\s*\Z/i)
              # Extract the IP address and strip any surrounding whitespace
              ips << match[2].strip
            end
          end
        end

        ips
      end
    end
  end
end
