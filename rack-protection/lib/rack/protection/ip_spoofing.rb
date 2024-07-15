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
        return [] unless forwarded_header_hash = Rack::Utils.forwarded_values(forwarded_header)

        (forwarded_header_hash.fetch(:for, []) + forwarded_header_hash.fetch(:by, [])).map { |ip| ip.gsub(/\[|\]/, "")  }
      end
    end
  end
end
