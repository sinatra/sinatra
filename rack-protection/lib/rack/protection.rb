require 'rack/protection/version'
require 'rack'

module Rack
  module Protection
    autoload :AuthenticityToken, 'rack/protection/authenticity_token'
    autoload :Base,              'rack/protection/base'
    autoload :EscapedParams,     'rack/protection/escaped_params'
    autoload :FormToken,         'rack/protection/form_token'
    autoload :FrameOptions,      'rack/protection/frame_options'
    autoload :IPSpoofing,        'rack/protection/ip_spoofing'
    autoload :JsonCsrf,          'rack/protection/json_csrf'
    autoload :PathTraversal,     'rack/protection/path_traversal'
    autoload :RemoteReferrer,    'rack/protection/remote_referrer'
    autoload :RemoteToken,       'rack/protection/remote_token'
    autoload :SessionHijacking,  'rack/protection/session_hijacking'
    autoload :XSSHeader,         'rack/protection/xss_header'

    def self.new(app, options = {})
      # does not include: RemoteReferrer, AuthenticityToken and FormToken
      except = Array options[:except]
      Rack::Builder.new do
        use EscapedParams,    options unless except.include? :escaped_params
        use FrameOptions,     options unless except.include? :frame_options
        use IPSpoofing,       options unless except.include? :ip_spoofing
        use JsonCsrf,         options unless except.include? :json_csrf
        use PathTraversal,    options unless except.include? :path_traversal
        use RemoteToken,      options unless except.include? :remote_token
        use SessionHijacking, options unless except.include? :session_hijacking
        use XSSHeader,        options unless except.include? :xss_header
        run app
      end.to_app
    end
  end
end
