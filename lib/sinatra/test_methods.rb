require 'uri'

module Sinatra
      
  module TestMethods

    %w(get post put delete).each do |verb|
      module_eval <<-end_eval
        def #{verb}_it(path, params = {})
          request = Rack::MockRequest.new(Sinatra::Dispatcher.new)
          @response = request.#{verb} path, :input => generate_input(params)
          body
        end
      end_eval
    end
        
    def response
      @response || Rack::MockResponse.new(404, {}, '')
    end

    def status
      response.status
    end

    def text
      response.body
    end
    alias :xml :text
    alias :html :text
    alias :body :text

    def headers
      response.headers
    end
    
    private
    
      def generate_input(params)
        params.map { |k,v| "#{k}=#{URI.escape(v)}" }.join('&')
      end

  end
  
end
