require 'sinatra/base'
require 'backports'

module Sinatra
  # = Sinatra::Cookies
  #
  # Easy way to deal with cookies
  #
  # == Usage
  #
  # Allows you to read cookies:
  #
  #   get '/' do
  #     "value: #{cookies[:something]}"
  #   end
  #
  # And of course to write cookies:
  #
  #   get '/set' do
  #     cookies[:something] = 'foobar'
  #     redirect to('/')
  #   end
  #
  # And generally behaves like a hash:
  #
  #   get '/demo' do
  #     cookies.merge! 'foo' => 'bar', 'bar' => 'baz'
  #     cookies.keep_if { |key, value| key.start_with? 'b' }
  #     foo, bar = cookies.values_at 'foo', 'bar'
  #     "size: #{cookies.length}"
  #   end
  #
  # === Classic Application
  #
  # In a classic application simply require the helpers, and start using them:
  #
  #     require "sinatra"
  #     require "sinatra/cookies"
  #
  #     # The rest of your classic application code goes here...
  #
  # === Modular Application
  #
  # In a modular application you need to require the helpers, and then tell
  # the application to use them:
  #
  #     require "sinatra/base"
  #     require "sinatra/cookies"
  #
  #     class MyApp < Sinatra::Base
  #       helpers Sinatra::Cookies
  #
  #       # The rest of your modular application code goes here...
  #     end
  #
  module Cookies
    class Jar
      include Enumerable
      attr_reader :options

      def initialize(app)
        @response_string = nil
        @response_hash   = {}
        @response        = app.response
        @request         = app.request
        @deleted         = []

        @options = {
          :path => @request.script_name.to_s.empty? ? '/' : @request.script_name,
          :domain => @request.host == 'localhost' ? nil : @request.host,
          :secure   => @request.secure?,
          :httponly => true
        }

        if app.settings.respond_to? :cookie_options
          @options.merge! app.settings.cookie_options
        end
      end

      def ==(other)
        other.respond_to? :to_hash and to_hash == other.to_hash
      end

      def [](key)
        response_cookies[key.to_s] || request_cookies[key.to_s]
      end

      def []=(key, value)
        @response.set_cookie key.to_s, @options.merge(:value => value)
      end

      def assoc(key)
        to_hash.assoc(key.to_s)
      end if Hash.method_defined? :assoc

      def clear
        each_key { |k| delete(k) }
      end

      def compare_by_identity?
        false
      end

      def default
        nil
      end

      alias default_proc default

      def delete(key)
        result = self[key]
        @response.delete_cookie(key.to_s, @options)
        result
      end

      def delete_if
        return enum_for(__method__) unless block_given?
        each { |k, v| delete(k) if yield(k, v) }
        self
      end

      def each(&block)
        return enum_for(__method__) unless block_given?
        to_hash.each(&block)
      end

      def each_key(&block)
        return enum_for(__method__) unless block_given?
        to_hash.each_key(&block)
      end

      alias each_pair each

      def each_value(&block)
        return enum_for(__method__) unless block_given?
        to_hash.each_value(&block)
      end

      def empty?
        to_hash.empty?
      end

      def fetch(key, &block)
        response_cookies.fetch(key.to_s) do
          request_cookies.fetch(key.to_s, &block)
        end
      end

      def flatten
        to_hash.flatten
      end if Hash.method_defined? :flatten

      def has_key?(key)
        response_cookies.has_key? key.to_s or request_cookies.has_key? key.to_s
      end

      def has_value?(value)
        response_cookies.has_value? value or request_cookies.has_value? value
      end

      def hash
        to_hash.hash
      end

      alias include? has_key?
      alias member?  has_key?

      def index(value)
        warn "Hash#index is deprecated; use Hash#key" if RUBY_VERSION > '1.9'
        key(value)
      end

      def inspect
        "<##{self.class}: #{to_hash.inspect[1..-2]}>"
      end

      def invert
        to_hash.invert
      end if Hash.method_defined? :invert

      def keep_if
        return enum_for(__method__) unless block_given?
        delete_if { |*a| not yield(*a) }
      end

      def key(value)
        to_hash.key(value)
      end

      alias key? has_key?

      def keys
        to_hash.keys
      end

      def length
        to_hash.length
      end

      def merge(other, &block)
        to_hash.merge(other, &block)
      end

      def merge!(other)
        other.each_pair do |key, value|
          if block_given? and include? key
            self[key] = yield(key.to_s, self[key], value)
          else
            self[key] = value
          end
        end
      end

      def rassoc(value)
        to_hash.rassoc(value)
      end

      def rehash
        response_cookies.rehash
        request_cookies.rehash
        self
      end

      def reject(&block)
        return enum_for(__method__) unless block_given?
        to_hash.reject(&block)
      end

      alias reject! delete_if

      def replace(other)
        select! { |k, v| other.include?(k) or other.include?(k.to_s)  }
        merge! other
      end

      def select(&block)
        return enum_for(__method__) unless block_given?
        to_hash.select(&block)
      end

      alias select! keep_if if Hash.method_defined? :select!

      def shift
        key, value = to_hash.shift
        delete(key)
        [key, value]
      end

      alias size length

      def sort(&block)
        to_hash.sort(&block)
      end if Hash.method_defined? :sort

      alias store []=

      def to_hash
        request_cookies.merge(response_cookies)
      end

      def to_a
        to_hash.to_a
      end

      def to_s
        to_hash.to_s
      end

      alias update merge!
      alias value? has_value?

      def values
        to_hash.values
      end

      def values_at(*list)
        list.map { |k| self[k] }
      end

      private

      def warn(message)
        super "#{caller.first[/^[^:]:\d+:/]} warning: #{message}"
      end

      def deleted
        parse_response
        @deleted
      end

      def response_cookies
        parse_response
        @response_hash
      end

      def parse_response
        string = @response['Set-Cookie']
        return if @response_string == string

        hash = {}

        string.each_line do |line|
          key, value = line.split(';', 2).first.to_s.split('=', 2)
          next if key.nil?
          key = Rack::Utils.unescape(key)
          if line =~ /expires=Thu, 01[-\s]Jan[-\s]1970/
            @deleted << key
          else
            @deleted.delete key
            hash[key] = value
          end
        end

        @response_hash.replace hash
        @response_string = string
      end

      def request_cookies
        @request.cookies.reject { |key, value| deleted.include? key }
      end
    end

    def cookies
      @cookies ||= Jar.new(self)
    end
  end

  helpers Cookies
end
