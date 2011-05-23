require 'rack/protection'

module Rack
  module Protection
    class RemoteToken < AuthenticityToken
    end
  end
end
