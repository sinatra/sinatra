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

      def easy_env_map
        {
          :accept => 'HTTP_ACCEPT',
          :agent => 'HTTP_AGENT',
          :host => 'HTTP_POST'
        }
      end
    
      def map_easys(params)
        easy_env_map.inject(params.dup) do |m, (from, to)|
          m[to] = m.delete(from) if m.has_key?(from); m
        end
      end

      %w(get head post put delete).each do |m|
        define_method("#{m}_it") do |path, *args|
          request = Rack::MockRequest.new(Sinatra.build_application)
          env, input = if args.size == 2
            [args.last, args.first]
          elsif args.size == 1
            data = args.first
            data.is_a?(Hash) ? [data.delete(:env), data.to_params] : [nil, data]
          end
          @response = request.request(m.upcase, path, {:input => input}.merge(env || {}))
        end
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
