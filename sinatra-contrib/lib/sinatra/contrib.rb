# frozen_string_literal: true

require 'sinatra/contrib/setup'

module Sinatra
  module Contrib
    ##
    # Common middleware that doesn't bring run time overhead if not used
    # or breaks if external dependencies are missing. Will extend
    # Sinatra::Application by default.
    module Common
      register :ConfigFile, 'sinatra/config_file'
      register :MultiRoute, 'sinatra/multi_route'
      register :Namespace, 'sinatra/namespace'
      register :RespondWith, 'sinatra/respond_with'

      helpers :Capture, 'sinatra/capture'
      helpers :ContentFor, 'sinatra/content_for'
      helpers :Cookies, 'sinatra/cookies'
      helpers :EngineTracking, 'sinatra/engine_tracking'
      helpers :JSON, 'sinatra/json'
      helpers :LinkHeader, 'sinatra/link_header'
      helpers :Streaming, 'sinatra/streaming'
      helpers :RequiredParams, 'sinatra/required_params'
    end

    ##
    # Other extensions you don't want to be loaded unless needed.
    module Custom
      register :Reloader, 'sinatra/reloader'

      helpers :HamlHelpers, 'sinatra/haml_helpers'
    end

    ##
    # Stuff that aren't Sinatra extensions, technically.
    autoload :Extension, 'sinatra/extension'
    autoload :TestHelpers, 'sinatra/test_helpers'
  end

  register Sinatra::Contrib::Common
end
