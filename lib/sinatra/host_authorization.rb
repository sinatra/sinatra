# frozen_string_literal: true

module Sinatra
    module HostAuthorization
      def self.registered(app)
        # Set default permitted hosts based on environment
        default_permitted_hosts = if app.development?
            ['localhost', '127.0.0.1', '::1']
        else
            nil # In production, require explicit configuration
        end

        app.set :permitted_hosts, default_permitted_hosts
        app.set :host_authorization_reaction, :block # Options: :raise, :redirect, :log, :block

        app.use Middleware
      end
  
      class Middleware
        def initialize(app)
            @app = app
            @permitted_hosts = app.settings.permitted_hosts
            @reaction = app.settings.host_authorization_reaction
        end
    
        def call(env)
            return @app.call(env) if @permitted_hosts.nil? || @permitted_hosts.empty?

            request = Rack::Request.new(env)
            host = extract_host(request, env)

            unless host_allowed?(host)
                handle_unpermitted_host(env)
            else
                @app.call(env)
            end
        end

        private

        def extract_host(request, env)
            if @app.settings.trust_forwarded_host
                if env['HTTP_FORWARDED']
                    # Parse the Forwarded header
                    forwarded_host = parse_forwarded_header(env['HTTP_FORWARDED'])
                    return forwarded_host if forwarded_host
                elsif env['HTTP_X_FORWARDED_HOST']
                    return env['HTTP_X_FORWARDED_HOST'].split(/,\s?/).last
                end
            end
            request.host
        end

        def parse_forwarded_header(header)
            # Simple parser for the Forwarded header
            # Example: Forwarded: for=192.0.2.60; proto=http; host=example.com
            header.split(';').each do |part|
                name, value = part.strip.split('=')
                return value if name.downcase == 'host'
            end
            nil
        end

        def host_allowed?(host)
            @permitted_hosts.any? do |pattern|
                case pattern
                    when String
                        pattern == host
                    when Regexp
                        pattern.match?(host)
                    else
                        false
                end
            end
        end

        def handle_unpermitted_host(env)
            case @reaction
                when :raise
                    raise Sinatra::HostAuthorization::HostNotAllowedError, "Blocked host: #{extract_host(nil, env)}"
                when :redirect
                    # Redirect to a safe host or URL
                    [302, { 'Location' => 'https://your-safe-domain.com' }, []]
                when :log
                    # Log the event and proceed
                    if @app.respond_to?(:logger) && @app.logger
                    @app.logger.warn "Blocked host: #{extract_host(nil, env)}"
                    else
                    env['rack.errors'] << "Blocked host: #{extract_host(nil, env)}\n"
                    end
                    @app.call(env)
                when :block
                    # Return 400 Bad Request
                    [400, { 'Content-Type' => 'text/plain' }, ['Bad Request - Host not allowed']]
                else
                    # Default action is to block
                    [400, { 'Content-Type' => 'text/plain' }, ['Bad Request - Host not allowed']]
            end
        end
      end

      class HostNotAllowedError < StandardError; end
    end

    register HostAuthorization
end
