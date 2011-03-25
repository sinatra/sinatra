require 'sinatra/contrib/setup'

module Sinatra
  module Contrib
    ##
    # Common middleware that doesn't bring run time overhead if not used
    # or breaks if external dependencies are missing. Will extend
    # Sinatra::Application by default.
    module Common
      register :ConfigFile
      register :Decompile
      register :Namespace
      register :RespondWith
      helpers :LinkHeader
    end

    ##
    # Other extensions you don't want to be loaded unless needed.
    module Custom
    end

    ##
    # Stuff that aren't Sinatra extensions, technically.
    autoload :TestHelpers
  end

  register Sinatra::Contrib::Common
end
