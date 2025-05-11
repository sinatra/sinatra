# frozen_string_literal: true

require 'rack/protection'

module Rack
  module Protection
    ##
    # Prevented attack::   XSS and others
    # Supported browsers:: Firefox 23+, Safari 7+, Chrome 25+, Opera 15+
    #
    # Description:: Content Security Policy, a mechanism web applications
    #               can use to mitigate a broad class of content injection
    #               vulnerabilities, such as cross-site scripting (XSS).
    #               Content Security Policy is a declarative policy that lets
    #               the authors (or server administrators) of a web application
    #               inform the client about the sources from which the
    #               application expects to load resources.
    #
    # More info::   W3C CSP Level 1 : https://www.w3.org/TR/CSP1/ (deprecated)
    #               W3C CSP Level 2 : https://www.w3.org/TR/CSP2/ (current)
    #               W3C CSP Level 3 : https://www.w3.org/TR/CSP3/ (draft)
    #               https://developer.mozilla.org/en-US/docs/Web/Security/CSP
    #               http://caniuse.com/#search=ContentSecurityPolicy
    #               http://content-security-policy.com/
    #               https://securityheaders.io
    #               https://scotthelme.co.uk/csp-cheat-sheet/
    #               http://www.html5rocks.com/en/tutorials/security/content-security-policy/
    #
    # Sets the 'content-security-policy[-report-only]' header.
    #
    # Options: ContentSecurityPolicy configuration is a complex topic with
    #          several levels of support that has evolved over time.
    #          See the W3C documentation and the links in the more info
    #          section for CSP usage examples and best practices. The
    #          CSP3 directives in the 'NO_ARG_DIRECTIVES' constant need to be
    #          presented in the options hash with a boolean 'true' in order
    #          to be used in a policy.
    #
    class ContentSecurityPolicy < Base
      default_options default_src: "'self'", report_only: false

      # Please try to maintain this
      # list from https://www.w3.org/TR/CSP3/#csp-directives
      SUPPORTED_DIRECTIVES = %i[
        child_src
        connect_src
        default_src
        font_src
        frame_src
        img_src
        manifest_src
        media_src
        object_src
        script_src
        script_src_elem
        script_src_attr
        style_src
        style_src_elem
        style_src_attr
        webrtc
        worker_src
        base_uri
        sandbox
        form_action
        frame_ancestors
        report_uri
        report_to
        upgrade_insecure_requests
      ].freeze

      DEPRECATED_DIRECTIVES = [
        # https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Content-Security-Policy/block-all-mixed-content
        :block_all_mixed_content,
        # https://github.com/w3c/webappsec-csp/issues/194
        :disown_opener,
        # https://github.com/w3c/webappsec-csp/pull/456
        :plugin_types,
        # https://web.archive.org/web/20250320135738/https://centralcsp.com/directives/referrer
        :referrer,
        # https://security.stackexchange.com/questions/223022/what-was-the-real-reason-for-dropping-reflected-xss-directive-from-csp
        :reflected_xss,
        # https://udn.realityripple.com/docs/Web/HTTP/Headers/Content-Security-Policy/require-sri-for https://security.stackexchange.com/questions/180450/why-does-chrome-tell-me-that-the-csp-require-sri-for-directive-is-implemented
        :require_sri_for,
        :webrtc_src,
        # https://content-security-policy.com/navigate-to/
        :navigate_to,
        # https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Content-Security-Policy/prefetch-src
        :prefetch_src,
      ].freeze

      DIRECTIVES = (SUPPORTED_DIRECTIVES + DEPRECATED_DIRECTIVES).freeze
      NO_ARG_DIRECTIVES = [
        :disown_opener,
        :block_all_mixed_content,
        :upgrade_insecure_requests,
      ]

      def csp_policy
        directives = []

        DIRECTIVES.each do |d,type|
          if options.key?(d)
            if NO_ARG_DIRECTIVES.include?(d)
              if options[d].is_a?(TrueClass)
                directives << d.to_s.tr('_', '-')
              end
            else
              directives << "#{d.to_s.sub(/_/, '-')} #{options[d]}"
            end
          end
        end

        directives.compact.sort.join('; ')
      end

      def call(env)
        status, headers, body = @app.call(env)
        header = options[:report_only] ? 'content-security-policy-report-only' : 'content-security-policy'
        headers[header] ||= csp_policy if html? headers
        [status, headers, body]
      end
    end
  end
end
