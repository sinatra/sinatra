module Sinatra
  
  module Test
    
    module Methods

      def easy_env_map
        {
          :accept => "HTTP_ACCEPT",
          :agent => "HTTP_USER_AGENT",
          :host => "HTTP_HOST",
          :session => "HTTP_COOKIE",
          :cookies => "HTTP_COOKIE"
        }
      end
      
      def session(data, key = 'rack.session')
        data = data.from_params if data.respond_to?(:from_params)
        "#{Rack::Utils.escape(key)}=#{[Marshal.dump(data)].pack("m*")}"
      end
          
      def map_easys(params)
        easy_env_map.inject(params.dup) do |m, (from, to)|
          m[to] = m.delete(from) if m.has_key?(from); m
        end
      end

      %w(get head post put delete).each do |m|
        define_method("#{m}_it") do |path, *args|
          env, input = if args.size == 2
            [args.last, args.first]
          elsif args.size == 1
            data = args.first
            data.is_a?(Hash) ? [map_easys(data.delete(:env) || {}), data.to_params] : [nil, data]
          end
          @request = Rack::MockRequest.new(Sinatra.build_application)
          @response = @request.request(m.upcase, path, {:input => input}.merge(env || {}))
        end
      end
      
      def follow!
        get_it(@response.location)
      end

      def method_missing(name, *args)
        @response.send(name, *args) rescue super
      end
      
    end

  end
  
end
