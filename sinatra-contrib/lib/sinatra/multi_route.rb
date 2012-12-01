require 'sinatra/base'

module Sinatra
  # = Sinatra::MultiRoute
  #
  # Create multiple routes with one statement.
  #
  # == Usage
  #
  # Use this extension to create a handler for multiple routes:
  #
  #   get '/foo', '/bar' do
  #     # ...
  #   end
  #
  # Or for multiple verbs:
  #
  #   route :get, :post, '/' do
  #     # ...
  #   end
  #
  # Or for multiple verbs and multiple routes:
  #
  #   route :get, :post, ['/foo', '/bar'] do
  #     # ...
  #   end
  #
  # Or even for custom verbs:
  #
  #   route 'LIST', '/' do
  #     # ...
  #   end
  #
  # === Classic Application
  #
  # To use the extension in a classic application all you need to do is require
  # it:
  #
  #     require "sinatra"
  #     require "sinatra/multi_route"
  #
  #     # Your classic application code goes here...
  #
  # === Modular Application
  #
  # To use the extension in a modular application you need to require it, and
  # then, tell the application you will use it:
  #
  #     require "sinatra/base"
  #     require "sinatra/multi_route"
  #
  #     class MyApp < Sinatra::Base
  #       register Sinatra::MultiRoute
  #
  #       # The rest of your modular application code goes here...
  #     end
  #
  module MultiRoute
    def head(*args, &block)     super(*route_args(args), &block)  end
    def delete(*args, &block)   super(*route_args(args), &block)  end
    def get(*args, &block)      super(*route_args(args), &block)  end
    def options(*args, &block)  super(*route_args(args), &block)  end
    def patch(*args, &block)    super(*route_args(args), &block)  end
    def post(*args, &block)     super(*route_args(args), &block)  end
    def put(*args, &block)      super(*route_args(args), &block)  end

    def route(*args, &block)
      options = Hash === args.last ? args.pop : {}
      routes = [*args.pop]
      args.each do |verb|
        verb = verb.to_s.upcase if Symbol === verb
        routes.each do |route|
          super(verb, route, options, &block)
        end
      end
    end

    private

    def route_args(args)
      options = Hash === args.last ? args.pop : {}
      [args, options]
    end
  end

  register MultiRoute
end
