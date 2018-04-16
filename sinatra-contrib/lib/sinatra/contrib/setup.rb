require 'sinatra/base'
require 'sinatra/contrib/version'
require 'backports/rails/string' # for String#underscore

module Sinatra
  module Contrib
    module Loader
      def extensions
        @extensions ||= {:helpers => [], :register => []}
      end

      def register(name, path = nil)
        autoload name, path, :register
      end

      def helpers(name, path = nil)
        autoload name, path, :helpers
      end

      def autoload(name, path = nil, method = nil)
        path ||= "sinatra/#{name.to_s.underscore}"
        extensions[method] << name if method
        Sinatra.autoload(name, path)
      end

      def registered(base)
        @extensions.each do |method, list|
          list = list.map { |name| Sinatra.const_get name }
          base.send(method, *list) unless base == ::Sinatra::Application
        end
      end
    end

    module Common
      extend Loader
    end

    module Custom
      extend Loader
    end

    module All
      def self.registered(base)
        base.register Common, Custom
      end
    end

    extend Loader
    def self.registered(base)
      base.register Common, Custom
    end
  end
end
