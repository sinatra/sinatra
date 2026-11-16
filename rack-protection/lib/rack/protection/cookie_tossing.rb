# frozen_string_literal: true

require 'rack/protection'
require 'pathname'

module Rack
  module Protection
    ##
    # Prevented attack::   Cookie Tossing
    # Supported browsers:: all
    # More infos::         https://github.com/blog/1466-yummy-cookies-across-domains
    #
    # Does not accept HTTP requests if the
    # {Cookie header}[https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Cookie] 
    # contains more than one session cookie. This does not protect against a cookie overflow attack.
    #
    # == Options
    #
    # [<tt>:session_key</tt>] The name of the session cookie (default: 'rack.session')
    #
    # [Rack::Protection::Base options] any option supported by Rack::Protection::Base.
    #
    # == Example: Default session key
    #
    #   use Rack::Protection::CookieTossing
    #
    # == Example: Custom session key
    #
    #   use Rack::Session::Cookie, key: "custom.session"
    #   use Rack::Protection::CookieTossing, session_key: "custom.session"
    class CookieTossing < Base
      default_reaction :deny

      def call(env)
        status, headers, body = super
        response = Rack::Response.new(body, status, headers)
        request = Rack::Request.new(env)
        remove_bad_cookies(request, response)
        response.finish
      end

      def accepts?(env)
        bad_cookies(env).empty?
      end

      def remove_bad_cookies(request, response)
        names = bad_cookies(request.env)
        return if names.empty?

        paths = cookie_paths(request.path)
        names.each do |name|
          paths.each { |path| response.set_cookie name, empty_cookie(request.host, path) }
        end
      end

      def redirect(env)
        request = Request.new(env)
        warn env, "attack prevented by #{self.class}"
        [302, { 'content-type' => 'text/html', 'location' => request.path }, []]
      end

      # The names of the session cookies of this request that are not
      # the one session cookie. The middleware instance serves every
      # request, so they must not be kept on it.
      def bad_cookies(env)
        cookies = Rack::Utils.parse_query(env['HTTP_COOKIE'], ';,') { |s| s }
        cookies.filter_map do |k, v|
          k if (k == session_key && Array(v).size > 1) ||
               (k != session_key && Rack::Utils.unescape(k) == session_key)
        end
      end

      def cookie_paths(path)
        path = '/' if path.to_s.empty?
        paths = []
        Pathname.new(path).descend { |p| paths << p.to_s }
        paths
      end

      def empty_cookie(host, path)
        { value: '', domain: host, path: path, expires: Time.at(0) }
      end

      def session_key
        @session_key ||= options[:session_key]
      end
    end
  end
end
