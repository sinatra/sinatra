# taken from Cheat

# get '/foo/(\w+)'
#  ... important code ...
# 
#   respond_to do |wants|
#     wants.html { render :something }
#     wants.text { "Just some text." }
#     wants.yaml { "Something neat!".to_yaml }
#     wants.xml  { "Also, XML.".to_xml }
#   end
# end

module Sinatra
  module Responder
    def respond_to
      yield response = Response.new(request.env["HTTP_ACCEPT"])
      headers 'Content-Type' => response.content_type
      body response.body
    end

    class Response
      attr_reader :body, :content_type
      def initialize(accept) @accept = accept end

      TYPES = {
        :yaml => %w[application/yaml text/yaml],
        :text => %w[text/plain],
        :html => %w[text/html */* application/html],
        :xml  => %w[application/xml],
        :json => %w[application/json]
      }

      def method_missing(method, *args)
        if TYPES[method] && @accept =~ Regexp.union(*TYPES[method])
          @content_type = TYPES[method].first 
          @body = yield if block_given?
        end
      end
    end
  end
end
