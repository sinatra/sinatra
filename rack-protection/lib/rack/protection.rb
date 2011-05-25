require 'rack/protection/version'
require 'rack'

module Rack
  module Protection
    autoload :AuthenticityToken, 'rack/protection/authenticity_token'
    autoload :Base,              'rack/protection/base'
    autoload :EscapedParams,     'rack/protection/escaped_params'
    autoload :FormToken,         'rack/protection/form_token'
    autoload :FrameOptions,      'rack/protection/frame_options'
    autoload :NoReferrer,        'rack/protection/no_referrer'
    autoload :PathTraversal,     'rack/protection/path_traversal'
    autoload :RemoteReferrer,    'rack/protection/remote_referrer'
    autoload :RemoteToken,       'rack/protection/remote_token'
    autoload :SessionHijacking,  'rack/protection/session_hijacking'
    autoload :XSSHeader,         'rack/protection/xss_header'

    def self.new(app, options = {})
      # does not include: AuthenticityToken, FormToken and NoReferrer
      except = Array options[:except]
      Rack::Builder.new do
        use EscapedParams,    options unless except.include? :escaped_params
        use FrameOptions,     options unless except.include? :frame_options
        use PathTraversal,    options unless except.include? :path_traversal
        use RemoteReferrer,   options unless except.include? :remote_referrer
        use RemoteToken,      options unless except.include? :remote_token
        use SessionHijacking, options unless except.include? :session_hijacking
        use XSSHeader,        options unless except.include? :xss_header
        run app
      end.to_app
    end
  end
end
