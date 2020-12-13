module Sinatra
  # = Sinatra::QuietLogger
  #
  # QuietLogger extension allows you to define paths excluded
  # from logging using the +quiet_logger_prefixes+ setting.
  # It is inspired from rails quiet_logger, but handles multiple paths.
  #
  # == Usage
  #
  # === Classic Application
  #
  # You have to require the quiet_logger, set the prefixes
  # and register the extension in your application.
  #
  #     require 'sinatra'
  #     require 'sinatra/quiet_logger'
  #
  #     set :quiet_logger_prefixes, %w(css js images fonts)
  #     register Sinatra::QuietLogger
  #
  # === Modular Application
  #
  # The same for modular application:
  #
  #     require 'sinatra/base'
  #     require 'sinatra/quiet_logger'
  #
  #     set :quiet_logger_prefixes, %w(css js images fonts)
  #
  #     class App < Sinatra::Base
  #       register Sinatra::QuietLogger
  #     end
  #
  module QuietLogger

    def self.registered(app)
      quiet_logger_prefixes = app.settings.quiet_logger_prefixes.join('|') rescue ''
      return warn('You need to specify the paths you wish to exclude from logging via `set :quiet_logger_prefixes, %w(images css fonts)`') if quiet_logger_prefixes.empty?
      const_set('QUIET_LOGGER_REGEX', %r(\A/{0,2}(?:#{quiet_logger_prefixes})))
      ::Rack::CommonLogger.prepend(
        ::Module.new do
          def log(env, *)
            super unless env['PATH_INFO'] =~ QUIET_LOGGER_REGEX
          end
        end
      )
    end

  end
end
