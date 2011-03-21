# Rack is rather slow on releases at the moment. Moreover, we cannot upgrade to
# a new Rack version right away, as this would make us incompatible with Rails.
# We therefore apply fixes that have not yet made it into a Rack release here.
#
# The code in here is extracted from the Rack project.
#
# Copyright (C) 2007, 2008, 2009, 2010 Christian Neukirchen <purl.org/net/chneukirchen>
#
# Rack is freely distributable under the terms of an MIT-style license.
# See http://www.opensource.org/licenses/mit-license.php.
require 'rack'

if Rack.release <= "1.2"
  require 'rack/request'
  require 'rack/logger'
  require 'rack/methodoverride'

  module Rack
    class Request
      def ssl?
        @env['HTTPS'] == 'on' or
        @env['HTTP_X_FORWARDED_PROTO'] == 'https' or
        @env['rack.url_scheme'] == 'https'
      end
    end

    class Logger
      # In Rack 1.2 and earlier, Rack::Logger called env['rack.errors'].close,
      # which is forbidden in the SPEC and made it impossible to use Rack::Lint.
      # Also, it might close your log file after the first request, potentially
      # crashing your web server.
      def call(env)
        logger = ::Logger.new(env['rack.errors'])
        logger.level = @level
        env['rack.logger'] = logger
        @app.call(env)
      end
    end

    class MethodOverride
      HTTP_METHODS << "PATCH"
    end
  end
end