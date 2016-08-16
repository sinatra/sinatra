# -*- coding: utf-8 -*-
require 'rack/protection'

module Rack
  module Protection
    ##
    # Prevented attack::   XSS and others
    # Supported browsers:: Firefox 23+, Safari 7+, Chrome 25+, Opera 15+
    #                      http://caniuse.com/contentsecuritypolicy
    # More infos::         http://www.html5rocks.com/en/tutorials/security/content-security-policy/
    #                      http://content-security-policy.com/
    #
    # Sets Content-Security-Policy-Report(-Only) header to tell the browser what resource are allowed to load from which domain.
    #
    # Options:
    # (descriptions taken from http://www.html5rocks.com/en/tutorials/security/content-security-policy/)
    #
    # connect_src:: limits the origins to which you can connect (via XHR,
    #               WebSockets, and EventSource).
    #
    # font_src::    specifies the origins that can serve web fonts. Google’s 
    #               Web Fonts could be enabled via font-src 
    #               https://themes.googleusercontent.com
    #
    # frame_src::   lists the origins that can be embedded as frames. For 
    #               example: frame-src https://youtube.com would enable
    #               embedding YouTube videos, but no other origins.
    #
    # img_src::     defines the origins from which images can be loaded.
    #
    # media_src::   restricts the origins allowed to deliver video and audio.
    #
    # object_src::  allows control over Flash and other plugins.
    #
    # style_src::   is script-src’s counterpart for stylesheets.
    #
    # report_uri::  instruct the browser to POST JSON-formatted violation 
    #               reports to a location specified in a report-uri directive.
    #
    # report_only:: ask the browser to monitor a policy, reporting violations,
    #               but not enforcing the restrictions.
    #
    # sandbox::     if the sandbox directive is present, the page will be 
    #               treated as though it was loaded inside of an iframe with
    #               a sandbox attribute.
    class ContentSecurityPolicy < Base
      default_options :default_src => :none, :script_src => "'self'", :img_src => "'self'", :style_src => "'self'", :connect_src => "'self'", :report_only => false

      KEYS = [:default_src, :script_src, :connect_src, :font_src, :frame_src, :img_src, :media_src, :style_src, :object_src, :report_uri, :sandbox]

      def collect_options
        KEYS.collect do |k|
          "#{k.to_s.sub(/_/, '-')} #{options[k]}" if options.key?(k)
        end.compact.join('; ')
      end

      def call(env)
        status, headers, body = @app.call(env)
        header = options[:report_only] ? 'Content-Security-Policy-Report-Only' : 'Content-Security-Policy'
        headers[header] ||= collect_options if html? headers
        [status, headers, body]
      end
    end
  end
end
