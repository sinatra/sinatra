require 'rainbows'

module Rack
  module Handler
    class Rainbows
      def self.run(app, **options)
        rainbows_options = {
          listeners: ["#{options[:Host]}:#{options[:Port]}"],
          worker_processes: 1,
          timeout: 30,
          config_file: ::File.expand_path('rainbows.conf', __dir__),
        }

        ::Rainbows::HttpServer.new(app, rainbows_options).start.join
      end
    end

    register :rainbows, ::Rack::Handler::Rainbows
  end
end
