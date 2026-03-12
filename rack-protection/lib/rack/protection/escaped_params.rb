# frozen_string_literal: true

require 'rack/protection'
require 'rack/utils'
require 'tempfile'

begin
  require 'escape_utils'
rescue LoadError
end

module Rack
  module Protection
    ##
    # Prevented attack::   XSS
    # Supported browsers:: all
    # More infos::         http://en.wikipedia.org/wiki/Cross-site_scripting
    #
    # Automatically escapes <tt>Rack::Request#params</tt> so they can be embedded in HTML
    # or JavaScript without any further issues.
    #
    # == Options
    #
    # [<tt>:escape</tt>] What escaping modes to use. Should be Symbol or Array of Symbols of one of the following:
    #                    <tt>:html</tt>:: escape HTML
    #                    <tt>:url</tt>:: escape URLs
    #                    <tt>:javascript</tt>:: escape JavaScript (requires the <tt>escape_utils</tt>
    #                                           gem or a custom <tt>:escaper</tt>).
    #
    #                    Default is <tt>:html</tt>.
    #
    # [<tt>:escaper</tt>] Object to use for escaping. It must respond to the following methods:
    #                     <tt>#escape_url</tt>:: if <tt>:escape</tt> is or contains <tt>:url</tt>
    #                     <tt>#escape_html</tt>:: if <tt>:escape</tt> is or contains <tt>:html</tt>
    #                     <tt>#escape_javascript</tt>:: if <tt>:escape</tt> is or contains <tt>:javascript</tt>
    #
    #                     By default, this class is used for escaping, however this class
    #                     does not implement <tt>#escape_javascript</tt>.  If <tt>:escape</tt> is
    #                     or includes <tt>:javascript</tt>, an exception will be raised.
    #
    #                     To avoid this, include the {<tt>escape_utils</tt>}[https://rubygems.org/gems/escape_utils]
    #                     gem in your app, *or* provide your own <tt>:escaper</tt> object.
    #
    # [Rack::Protection::Base options] any option supported by Rack::Protection::Base.
    #
    # == Example: Default usage
    #
    #     use Rack::Protection::EscapedParams
    #
    # == Example: Escape URLs and HTML
    #
    #     use Rack::Protection::EscapedParams, escape: [:html, :url]
    #
    # == Example: Escape everything using custom escaper
    #
    #    module MyEscaper
    #      def self.escape_url(str)
    #        # your custom code here
    #      end
    #      def self.escape_html(str)
    #        # your custom code here
    #      end
    #      def self.escape_javascrtip(str)
    #        # your custom code here
    #      end
    #    end
    #    
    #    use Rack::Protection::EscapedParams, escape: [:html, :url, :javascript],
    #                                         escaper: MyEscaper
    class EscapedParams < Base
      extend Rack::Utils

      class << self
        alias escape_url escape
        public :escape_html
      end

      default_options escape: :html,
                      escaper: defined?(EscapeUtils) ? EscapeUtils : self

      def initialize(*)
        super

        modes       = Array options[:escape]
        @escaper    = options[:escaper]
        @html       = modes.include? :html
        @javascript = modes.include? :javascript
        @url        = modes.include? :url

        return unless @javascript && (!@escaper.respond_to? :escape_javascript)

        raise('Use EscapeUtils for JavaScript escaping.')
      end

      def call(env)
        request  = Request.new(env)
        get_was  = handle(request.GET)
        post_was = begin
          handle(request.POST)
        rescue StandardError
          nil
        end
        app.call env
      ensure
        request.GET.replace  get_was  if get_was
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
        when Tempfile then object
        end
      end

      def escape_hash(hash)
        hash = hash.dup
        hash.each { |k, v| hash[k] = escape(v) }
        hash
      end

      def escape_string(str)
        str = @escaper.escape_url(str)        if @url
        str = @escaper.escape_html(str)       if @html
        str = @escaper.escape_javascript(str) if @javascript
        str
      end
    end
  end
end
