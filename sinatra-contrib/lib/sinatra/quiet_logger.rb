# frozen_string_literal: true

require 'rack/protection'

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
    PATH_TRAVERSAL = ::Rack::Protection::PathTraversal.new(nil)

    def self.registered(app)
      quiet_logger_prefixes = begin
        app.settings.quiet_logger_prefixes.join('|')
      rescue StandardError
        ''
      end
      return warn('You need to specify the paths you wish to exclude from logging via `set :quiet_logger_prefixes, %w(images css fonts)`') if quiet_logger_prefixes.empty?

      @app = app
      const_set('QUIET_LOGGER_REGEX', %r(\A/{0,2}(?:#{quiet_logger_prefixes})))
      ::Rack::CommonLogger.prepend(
        ::Module.new do
          def log(env, *)
            super unless QuietLogger.routed_path(env['PATH_INFO'].to_s) =~ QUIET_LOGGER_REGEX
          end
        end
      )
    end

    # The path the app matched its routes on. Rack::Protection::PathTraversal
    # cleans the path for the app only, when the request is logged PATH_INFO
    # is back to what the client sent.
    def self.routed_path(path)
      path_traversal? ? PATH_TRAVERSAL.cleanup(path) : path
    end

    # Checked for each request, protection can be set after registering
    def self.path_traversal?
      protection = @app.protection
      except = protection[:except] if protection.is_a?(Hash)
      @app.protection? && !Array(except).include?(:path_traversal)
    end
  end
end
