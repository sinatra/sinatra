module Sinatra
  
  module Test
    
    module Methods
  
      def get_it(path, params = {})
        @request = Rack::MockRequest.new(Sinatra.application)
        @response = @request.get(path, :input => params.to_params)
      end

      def post_it(path, params = {})
        @request = Rack::MockRequest.new(Sinatra.application)
        @response = @request.post(path, :input => params.to_params)
      end

      def put_it(path, params = {})
        @request = Rack::MockRequest.new(Sinatra.application)
        @response = @request.put(path, :input => params.to_params)
      end

      def delete_it(path, params = {})
        @request = Rack::MockRequest.new(Sinatra.application)
        @response = @request.delete(path, :input => params.to_params)
      end
      
      def follow!
        get_it(@response.location)
      end

      def method_missing(name, *args)
        @response.send(name, *args)
      end
      
    end

  end
  
end
