class Rack::MockRequest
  class << self
    alias :env_for_without_env :env_for
    def env_for(uri = "", opts = {})
      env = { 'HTTP_USER_AGENT' => opts.delete(:agent) }
      env_for_without_env(uri, opts).merge(env)
    end
  end
end

module Sinatra
  
  module Test
    
    module Methods
  
      def get_it(path, params = {}, options = {})
        agent = params.delete(:agent)
        @request = Rack::MockRequest.new(Sinatra.application)
        @response = @request.get(path, options.merge(:input => params.to_params, :agent => agent))
      end

      def head_it(path, params = {}, options = {})
        agent = params.delete(:agent)
        @request = Rack::MockRequest.new(Sinatra.application)
        @response = @request.request('HEAD', path, options.merge(:input => params.to_params, :agent => agent))
      end

      def post_it(path, params = {}, options = {})
        agent = params.delete(:agent)
        @request = Rack::MockRequest.new(Sinatra.application)
        @response = @request.post(path, options.merge(:input => params.to_params, :agent => agent))
      end

      def put_it(path, params = {}, options = {})
        agent = params.delete(:agent)
        @request = Rack::MockRequest.new(Sinatra.application)
        @response = @request.put(path, options.merge(:input => params.to_params, :agent => agent))
      end

      def delete_it(path, params = {}, options = {})
        agent = params.delete(:agent)
        @request = Rack::MockRequest.new(Sinatra.application)
        @response = @request.delete(path, options.merge(:input => params.to_params, :agent => agent))
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
