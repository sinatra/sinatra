# frozen_string_literal: true

require 'rack/protection'

module Rack
  module Protection
    ##
    # Prevented attack::   XSS and others
    # Supported browsers:: Firefox 23+, Safari 7+, Chrome 25+, Opera 15+
    #
    # Sets the 'content-security-policy' or the 'content-security-policy-report-only]' header, based on options provided.
    #
    # Description:: Content Security Policy, is a mechanism web applications
    #               can use to mitigate a broad class of content injection
    #               vulnerabilities, such as cross-site scripting (XSS).
    #               Content Security Policy is a declarative policy that lets
    #               the authors (or server administrators) of a web application
    #               inform the client about the sources from which the
    #               application expects to load resources.
    #
    # More info::   * W3C CSP Level 1 : https://www.w3.org/TR/CSP1/ (deprecated)
    #               * W3C CSP Level 2 : https://www.w3.org/TR/CSP2/ (current)
    #               * W3C CSP Level 3 : https://www.w3.org/TR/CSP3/ (draft)
    #               * https://developer.mozilla.org/en-US/docs/Web/Security/CSP
    #               * http://caniuse.com/#search=ContentSecurityPolicy
    #               * http://content-security-policy.com/
    #               * https://securityheaders.io
    #               * https://scotthelme.co.uk/csp-cheat-sheet/
    #               * http://www.html5rocks.com/en/tutorials/security/content-security-policy/
    #
    # == Options
    #
    # ContentSecurityPolicy configuration is a complex topic with
    # several levels of support that has evolved over time.
    # See the W3C documentation and the links in the more info
    # section for CSP usage examples and best practices.
    #
    # [<tt>:report_only</tt>] - if true, the <tt>content-security-policy-report-only</tt> header is set, instead of <tt>content-security-policy</tt>. Note that in this case, you should also set the <tt>:report_uri</tt> option and the <tt>:report_to</tt> option.  If you *do* set <tt>:report_to</tt>, you must also set the `reporting-endpoints` header yourself.
    #
    # [<tt>:default_src</tt>] - sets the <tt>default-src</tt> directive, which acts as a fallback for any directive you don't specify. Default is <tt>'self'</tt>.
    #
    # [Any Supported CSP Directive, underscorized] - All supported CSP directives can be configured individually. See DIRECTIVES and NO_ARG_DIRECTIVES for a list of what is supported. Note that this list is not necessarly complete as the spec and browser behavior is constantly evovling (for example, <tt>script-src-elem</tt> is not supported).  Pass in an underscorized symbol. For example, to set the <tt>script-src</tt> directive, use <tt>:script_src</tt>.  The value should be whatever value you want set in the header. Note that for directives that do not take an argument, you must set their value to <tt>true</tt> to ensure they are set. See NO_ARG_DIRECTIVES. Note that <tt>'self'</tt> and <tt>'none'</tt> require single quotes and this middleware will not add them. For example, to disallow <tt>iframe</tt>s, you would need to use <tt>frame_src: "'none'"</tt>.
    #
    class ContentSecurityPolicy < Base
      default_options default_src: "'self'", report_only: false

      DIRECTIVES = %i[base_uri child_src connect_src default_src
                      font_src form_action frame_ancestors frame_src
                      img_src manifest_src media_src object_src
                      plugin_types referrer reflected_xss report_to
                      report_uri require_sri_for sandbox script_src
                      style_src worker_src webrtc_src navigate_to
                      prefetch_src].freeze

      NO_ARG_DIRECTIVES = %i[block_all_mixed_content disown_opener
                             upgrade_insecure_requests].freeze

      def csp_policy
        directives = []

        DIRECTIVES.each do |d|
          if options.key?(d)
            directives << "#{d.to_s.sub(/_/, '-')} #{options[d]}"
          end
        end

        # Set these key values to boolean 'true' to include in policy
        NO_ARG_DIRECTIVES.each do |d|
          if options.key?(d) && options[d].is_a?(TrueClass)
            directives << d.to_s.tr('_', '-')
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
