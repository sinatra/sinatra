module Sinatra
  
  module TestMethods

    @response = nil unless defined?("@response")

    def get_it(path)
      request = Rack::MockRequest.new(Sinatra::Dispatcher.new)
      @response = request.get path
    end

    def post_it(path)
      request = Rack::MockRequest.new(Sinatra::Dispatcher.new)
      @response = request.post path
    end

    def response
      @response
    end

    def status
      @response.status
    end

    def text
      @response.body
    end
    alias :xml :text
    alias :html :text
    alias :body :text

    def headers
      @response.headers
    end

  end
  
end
