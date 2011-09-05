require 'sinatra/contrib/setup'

module Sinatra
  module Contrib
    ##
    # Common middleware that doesn't bring run time overhead if not used
    # or breaks if external dependencies are missing. Will extend
    # Sinatra::Application by default.
    module Common
      register :ConfigFile
      register :MultiRoute
      register :Namespace
      register :RespondWith

      helpers :Capture
      helpers :ContentFor
      helpers :Cookies
      helpers :EngineTracking
      helpers :JSON
      helpers :LinkHeader
      helpers :Streaming
    end

    ##
    # Other extensions you don't want to be loaded unless needed.
    module Custom
      # register :Compass
      register :Decompile
      register :Reloader
    end

    ##
    # Stuff that aren't Sinatra extensions, technically.
    autoload :Extension
    autoload :TestHelpers
  end

  register Sinatra::Contrib::Common
end
