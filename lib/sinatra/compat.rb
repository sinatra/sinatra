require 'ostruct'
require 'sinatra/base'
require 'sinatra/main'

# Deprecated. Do we still need this?
if ENV['SWIFT']
  require 'swiftcore/swiftiplied_mongrel'
  puts "Using Swiftiplied Mongrel"
elsif ENV['EVENT']
  require 'swiftcore/evented_mongrel'
  puts "Using Evented Mongrel"
end

# Deprecated. Make Rack 0.9.0 backward compatibile with 0.4.0
# mime types
require 'rack/file'
class Rack::File
  unless defined? MIME_TYPES
    MIME_TYPES = Hash.new {|hash,key|
      Rack::Mime::MIME_TYPES[".#{key}"] }
  end
end

# Deprecated. Rack::Utils will not extend itself in the future. Sinatra::Base
# includes Rack::Utils, however.
module Rack::Utils ; extend self ; end

module Sinatra
  module Compat
  end

  # Deprecated. Use: error
  class ServerError < RuntimeError
    def code ; 500 ; end
  end

  class Default < Base
    # Deprecated.
    FORWARD_METHODS = Sinatra::Delegator::METHODS

    # Deprecated. Use: response['Header-Name']
    def headers(header=nil)
      response.headers.merge!(header) if header
      response.headers
    end
    alias :header :headers

    # Deprecated. Use: halt
    alias :stop :halt

    # Deprecated. Use: etag
    alias :entity_tag :etag

    # The :disposition option is deprecated; use: #attachment. This method
    # setting the Content-Transfer-Encoding header is deprecated.
    def send_file(path, opts={})
      opts[:disposition] = 'attachment' if !opts.key?(:disposition)
      attachment opts[:filename] || path if opts[:filename] || opts[:disposition]
      response['Content-Transfer-Encoding'] = 'binary' if opts[:disposition]
      super(path, opts)
    end

    def options ; self.class.options ; end

    class << self
      # Deprecated. Options are stored directly on the class object.
      def options ; Options.new(self) ; end

      class Options < Struct.new(:target) #:nodoc:
        def method_missing(name, *args, &block)
          if target.respond_to?(name)
            target.__send__(name, *args, &block)
          elsif args.empty? && name.to_s !~ /=$/
            nil
          else
            super
          end
        end
      end

      # Deprecated. Use: configure
      alias :configures :configure

      # Deprecated. Use: set
      def default_options
        fake = lambda { |options| set(options) }
        def fake.merge!(options) ; call(options) ; end
        fake
      end

      # Deprecated. Use: set
      alias :set_option :set
      alias :set_options :set

      # Deprecated. Use: set :environment, ENV
      def env=(value)
        set :environment, value
      end
      alias :env :environment
    end

    # Deprecated. Missing messages are no longer delegated to @response.
    def method_missing(name, *args, &b)
      if @response.respond_to?(name)
        @response.send(name, *args, &b)
      else
        super
      end
    end
  end

  class << self
    # Deprecated. Use: Sinatra::Application
    def application
      Sinatra::Application
    end

    # Deprecated. Use: error 404
    def not_found(&block)
      error 404, &block
    end

    # Deprecated. Use: Sinatra::Application.reset!
    def application=(value)
      raise ArgumentError unless value.nil?
      Sinatra.class_eval do
        remove_const :Application
        const_set :Application, Class.new(Sinatra::Default)
      end
    end

    # Deprecated. Use: Sinatra::Application
    alias :build_application :application

    # Deprecated.
    def options ; Sinatra::Application.options ; end
    def port ; options.port ; end
    def host ; options.host ; end
    def env ; options.environment  ; end
  end
end
