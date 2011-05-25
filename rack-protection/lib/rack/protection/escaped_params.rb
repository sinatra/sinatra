require 'rack/protection'
require 'escape_utils'

module Rack
  module Protection
    ##
    # Prevented attack::   XSS
    # Supported browsers:: all
    # More infos::         http://en.wikipedia.org/wiki/Cross-site_scripting
    #
    # Automatically escapes Rack::Request#params so they can be embedded in HTML
    # or JavaScript without any further issues. Calls +html_safe+ on the escaped
    # strings if defined, to avoid double-escaping in Rails. It does only escape
    # for embedding in HTML and Javascript by default, so you have to take care
    # of URLs or SQL injection yourself.
    #
    # Options:
    # escape:: What escaping modes to use, should be Symbol or Array of Symbols.
    #          Available: :html, :javascript, :url, default: [:html, :javascript]
    class EscapedParams < Base
      default_options :escape => [:html, :javascript]

      def initialize(*)
        super
        modes = Array options[:escape]
        code  = "def self.escape_string(str) %s end"
        modes.each { |m| code %= "EscapeUtils.escape_#{m}(%s)"}
        eval code % 'str'
      end

      def call(env)
        request  = Request.new(env)
        get_was  = handle(request.GET)
        post_was = handle(request.POST) rescue nil
        app.call env
      ensure
        request.GET.replace get_was
        request.POST.replace post_was if post_was
      end

      def handle(hash)
        was = hash.dup
        hash.replace escape(hash)
        was
      end

      def escape(object)
        case object
        when Hash   then escape_hash(object)
        when Array  then object.map { |o| escape(o) }
        when String then escape_string(object)
        else raise ArgumentError, "cannot escape #{object.inspect}"
        end
      end

      def escape_hash(hash)
        hash = hash.dup
        hash.each { |k,v| hash[k] = escape(v) }
        hash
      end
    end
  end
end
