module Sinatra

  # = Sinatra::CustomLogger
  #
  # CustomLogger extension allows you to define your own logger instance
  # using +logger+ setting. That logger then will be available
  # as #logger helper method in your routes and views.
  #
  # == Usage
  #
  # === Classic Application
  #
  # To define your custom logger instance in a classic application:
  #
  #     require 'sinatra'
  #     require 'sinatra/custom_logger'
  #     require 'logger'
  #
  #     set :logger, Logger.new(STDOUT)
  #
  #     get '/' do
  #       logger.info 'Some message' # STDOUT logger is used
  #       # Other code...
  #     end
  #
  # === Modular Application
  #
  # The same for modular application:
  #
  #     require 'sinatra/base'
  #     require 'sinatra/custom_logger'
  #     require 'logger'
  #
  #     class MyApp < Sinatra::Base
  #       helpers Sinatra::CustomLogger
  #
  #       configure :development, :production do
  #         logger = Logger.new(File.open("#{root}/log/#{environment}.log", 'a'))
  #         logger.level = Logger::DEBUG if development?
  #         set :logger, logger
  #       end
  #
  #       get '/' do
  #         logger.info 'Some message' # File-based logger is used
  #         # Other code...
  #       end
  #     end
  #
  module CustomLogger
    def logger
      if settings.respond_to?(:logger)
        settings.logger
      else
        request.logger
      end
    end
  end

  helpers CustomLogger
end
