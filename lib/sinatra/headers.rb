# frozen_string_literal: true

# :enddoc:

module Sinatra
  class Headers
    if Rack::RELEASE >= '3.0'
      MAP = {
        :content_type => 'content-type',
        :content_length => 'content-length',
      }
    else
      MAP = {
        :content_type => 'Content-Type',
        :content_length => 'Content-Length',
      }
    end
  end
end
