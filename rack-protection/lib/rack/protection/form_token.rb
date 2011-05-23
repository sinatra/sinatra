require 'rack/protection'

module Rack
  module Protection
    class FormToken < AuthenticityToken
    end
  end
end
