# frozen_string_literal: true

require 'sinatra/base'

module Sinatra
  # = Sinatra::RequiredParams
  #
  # Ensure required query parameters
  #
  # == Usage
  #
  # Set required query parameter keys in the argument.
  # It'll halt with 400 if required keys don't exist.
  #
  #   get '/simple_keys' do
  #     required_params :p1, :p2
  #   end
  #
  # Complicated pattern is also fine.
  #
  #   get '/complicated_keys' do
  #     required_params :p1, :p2 => [:p3, :p4]
  #   end
  #
  # === Classic Application
  #
  # In a classic application simply require the helpers, and start using them:
  #
  #     require "sinatra"
  #     require "sinatra/required_params"
  #
  #     # The rest of your classic application code goes here...
  #
  # === Modular Application
  #
  # In a modular application you need to require the helpers, and then tell
  # the application to use them:
  #
  #     require "sinatra/base"
  #     require "sinatra/required_params"
  #
  #     class MyApp < Sinatra::Base
  #       helpers Sinatra::RequiredParams
  #
  #       # The rest of your modular application code goes here...
  #     end
  #
  module RequiredParams
    def required_params(*keys)
      _required_params(params, *keys)
    end

    private

    def _required_params(p, *keys)
      keys.each do |key|
        if key.is_a?(Hash)
          _required_params(p, *key.keys)
          key.each do |k, v|
            _required_params(p[k.to_s], v)
          end
        elsif key.is_a?(Array)
          _required_params(p, *key)
        else
          halt 400 unless p.respond_to?(:key?) && p&.key?(key.to_s)
        end
      end
      true
    end
  end

  helpers RequiredParams
end
