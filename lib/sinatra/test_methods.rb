module Sinatra
  
  module TestMethods

    @response = nil unless defined?("@response")

    def get_it(path)
      request = Rack::MockRequest.new(Sinatra::Dispatcher.new)
      @response = request.get path
      body
    end

    def post_it(path)
      request = Rack::MockRequest.new(Sinatra::Dispatcher.new)
      @response = request.post path
      body
    end
    
    def put_it(path)
      request = Rack::MockRequest.new(Sinatra::Dispatcher.new)
      @response = request.put path
      body
    end
    
    def delete_it(path)
      request = Rack::MockRequest.new(Sinatra::Dispatcher.new)
      @response = request.delete path
      body
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
