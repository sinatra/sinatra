# frozen_string_literal: true

require 'rack/protection'

module Rack
  module Protection
    ##
    # Prevented attack::   Clickjacking
    # Supported browsers:: * Chrome 26 and later
    #                      * Edge 12 and later
    #                      * Safari 5.1 and later
    #                      * Mobile Safari 7 and later
    #                      * Firefox 4 and later
    #                      * Internet Explorer 8 and later
    #                      * See full details at https://caniuse.com/mdn-http_headers_content-security-policy_frame-ancestors
    # More info::          * https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/X-Frame-Options
    #                      * https://caniuse.com/x-frame-options
    #
    # Sets X-Frame-Options header to tell the browser avoid embedding the page
    # in a frame. Note that in modern browsers, the preferred approach is to use the
    # {frame-ancestors directive}[https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Content-Security-Policy/frame-ancestors]
    # in your content security policy.
    #
    # Notes:
    #
    # * This middleware won't do anything for non-HTML responses.
    # * If your app sets <tt>X-Frame-Options</tt> header, this middleware will not override it.
    #
    # == Options
    #
    # [<tt>:frame_options</tt>] Defines who should be allowed to embed the page in a
    #                           frame.
    #                           [<tt>:deny</tt>] forbid any embedding
    #                           [<tt>:sameorigin</tt>] allow embedding from the same origin
    #
    #                           The default is <tt>:sameorigin</tt>.
    #
    # [Rack::Protection::Base options] options supported by Rack::Protection::Base may affect this middleware.
    #
    # == Example: Default behavior
    #
    #     # Embedding from same origin is allowed
    #     use Rack::Protection::FrameOptions 
    #
    # == Example: Deny embedding
    #
    #     # Embedding is not allowed
    #     use Rack::Protection::FrameOptions, frame_options: :deny
    class FrameOptions < Base
      default_options frame_options: :sameorigin

      def frame_options
        @frame_options ||= begin
          frame_options = options[:frame_options]
          frame_options = options[:frame_options].to_s.upcase unless frame_options.respond_to? :to_str
          frame_options.to_str
        end
      end

      def call(env)
        status, headers, body        = @app.call(env)
        headers['x-frame-options'] ||= frame_options if html? headers
        [status, headers, body]
      end
    end
  end
end
