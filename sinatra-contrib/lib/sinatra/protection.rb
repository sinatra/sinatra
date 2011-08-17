require 'sinatra/base'
require 'rack/protection'

module Sinatra

  # = Sinatra::Protection
  #
  # Sets up {rack-protection}[https://github.com/rkh/rack-protection] to
  # prevent common attacks against your application.
  #
  # == Usage
  # The protection modes used can be configured by the +protection+ setting:
  #
  #   require 'sinatra'
  #   require 'sinatra/protection'
  #
  #   set :protection, :except => :path_traversal
  #
  # There are a few, partly protection specific options you can set, too:
  #
  #   set :protection,
  #     :reaction      => :deny,  # block malicious requests, alternative: :drop_session
  #     :frame_options => :deny   # do not allow any embedding in frames (default: :sameorigin)
  #     
  # For more information, see rack-protection.
  #
  # === Classic Application
  #
  # As with any other extension, you have to register this one manually in a
  # classic application:
  #
  #   require 'sinatra/base'
  #   require 'sinatra/protection'
  #
  #   class MyApp < Sinatra::Base
  #     register Sinatra::Protection
  #   end
  module Protection
    def setup_default_middleware(builder)
      super
      if protection
        options = protection == true ? {} : protection
        builder.use Rack::Protection, options
      end
    end
    
    def self.registered(base)
      base.enable :protection
    end
  end

  register Sinatra::Namespace
end
