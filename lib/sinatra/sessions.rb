module Sinatra
  module Session
    class Cookie
      def self.use=(v)
        @@use = v unless Sinatra::Server.running  # keep is thread-safe!
      end
      
      def initialize(app, options = {})
        @app = if (@@use ||= :on) == :off
          app
        else
          Rack::Session::Cookie.new(app)
        end
      end
      
      def call(env)
        @app.call(env)
      end
    end
  end
end
