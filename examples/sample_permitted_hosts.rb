# Usage in application
class MyApp < Sinatra::Base
    configure do
      set :permitted_hosts, ['example.com', /\.example\.com$/]
      set :host_authorization_reaction, :block # Options: :raise, :redirect, :log, :block
  
      # Additional settings
      set :trust_forwarded_host, false # Disabled by default
    end

    # Helpers for safe URL generation
    helpers do
      def safe_uri(path, absolute = false)
        return path unless absolute
  
        host = if settings.trust_forwarded_host
                 request.forwarded_host || request.host
               else
                 request.host
               end

        "#{request.scheme}://#{host}#{path}"
      end
    end
end
