module Sinatra

  module Test

    module Methods
      include Rack::Utils

      ENV_KEY_NAMES = {
        :accept => "HTTP_ACCEPT",
        :agent => "HTTP_USER_AGENT",
        :host => "HTTP_HOST",
        :session => "HTTP_COOKIE",
        :cookies => "HTTP_COOKIE",
        :content_type => "CONTENT_TYPE"
      }

      def session(data, key = 'rack.session')
        data = data.from_params if data.respond_to?(:from_params)
        "#{escape(key)}=#{[Marshal.dump(data)].pack("m*")}"
      end

      def normalize_rack_environment(env)
        env.inject({}) do |hash,(k,v)|
          hash[ENV_KEY_NAMES[k] || k] = v
          hash
        end
      end

      def hash_to_param_string(hash)
        hash.map { |pair| pair.map{|v|escape(v)}.join('=') }.join('&')
      end

      %w(get head post put delete).each do |verb|
        http_method = verb.upcase
        define_method("#{verb}_it") do |path, *args|
          @request = Rack::MockRequest.new(Sinatra.build_application)
          opts, input =
            case args.size
            when 2 # input, env
              input, env = args
              [env, input]
            when 1 # params
              if (data = args.first).kind_of?(Hash)
                env = (data.delete(:env) || {})
                [env, hash_to_param_string(data)]
              else
                [{}, data]
              end
            when 0
              [{}, '']
            else
              raise ArgumentError, "zero, one, or two arguments expected"
            end
          opts = normalize_rack_environment(opts)
          opts[:input] ||= input
          @response = @request.request(http_method, path, opts)
        end
      end

      def follow!
        get_it(@response.location)
      end

      def method_missing(name, *args)
        if @response.respond_to?(name)
          @response.send(name, *args)
        else
          super
        end
      end

    end

  end

end
