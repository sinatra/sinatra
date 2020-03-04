require 'sinatra/base'
require 'sinatra/contrib/version'

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
        path ||= "sinatra/#{underscore(name.to_s)}"
        extensions[method] << name if method
        Sinatra.autoload(name, path)
      end

      def registered(base)
        @extensions.each do |method, list|
          list = list.map { |name| Sinatra.const_get name }
          base.send(method, *list) unless base == ::Sinatra::Application
        end
      end

      private

      # https://github.com/marcandre/backports/blob/e01f4dfbf0cc5bf76151e408905b3be31948f2fe/lib/backports/rails/string.rb#L37-L44
      # Standard in rails. See official documentation[http://api.rubyonrails.org/classes/ActiveSupport/CoreExtensions/String/Inflections.html]
      def underscore(s)
        s.gsub(/::/, '/').
          gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
          gsub(/([a-z\d])([A-Z])/,'\1_\2').
          tr("-", "_").
          downcase
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
