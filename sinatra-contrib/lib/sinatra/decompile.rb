require 'sinatra/base'
require 'backports'
require 'uri'

module Sinatra

  # = Sinatra::Decompile
  #
  # <tt>Sinatra::Decompile</tt> is an extension that provides a method,
  # conveniently called +decompile+, that will generate a String pattern for a
  # given route.
  #
  # == Usage
  #
  # === Classic Application
  #
  # To use the extension in a classic application all you need to do is require
  # it:
  #
  #     require "sinatra"
  #     require "sinatra/decompile"
  #
  #     # Your classic application code goes here...
  #
  # This will add the +decompile+ method to the application/class scope, but
  # you can also call it as <tt>Sinatra::Decompile.decompile</tt>.
  #
  # === Modular Application
  #
  # To use the extension in a modular application you need to require it, and
  # then, tell the application you will use it:
  #
  #     require "sinatra/base"
  #     require "sinatra/decompile"
  #
  #     class MyApp < Sinatra::Base
  #       register Sinatra::Decompile
  #
  #       # The rest of your modular application code goes here...
  #     end
  #
  # This will add the +decompile+ method to the application/class scope.  You
  # can choose not to register the extension, but instead of calling
  # +decompile+, you will need to call <tt>Sinatra::Decompile.decompile</tt>.
  #
  module Decompile
    extend self

    ##
    # Regenerates a string pattern for a given route
    #
    # Example:
    #
    #   class Sinatra::Application
    #     routes.each do |verb, list|
    #       puts "#{verb}:"
    #       list.each do |data|
    #         puts "\t" << decompile(data)
    #       end
    #     end
    #   end
    #
    # Will return the internal Regexp if unable to reconstruct the pattern,
    # which likely indicates that a Regexp was used in the first place.
    #
    # You can also use this to check whether you could actually use a string
    # pattern instead of your regexp:
    #
    #   decompile /^/foo$/ # => '/foo'
    def decompile(pattern, keys = nil, *)
      # Everything in here is basically just the reverse of
      # Sinatra::Base#compile
      pattern, keys = pattern if pattern.respond_to? :to_ary
      keys, str     = keys.try(:dup), pattern.inspect
      return pattern unless str.start_with? '/' and str.end_with? '/'
      str.gsub! /^\/\^?|\$?\/$/, ''
      str.gsub! encoded(' '), ' '
      return pattern if str =~ /^[\.\+]/
      str.gsub! /\([^\(\)]*\)/ do |part|
        case part
        when '(.*?)'
          return pattern if keys.shift != 'splat'
          '*'
        when '([^\/?#]+)'
          return pattern if keys.empty?
          ":" << keys.shift
        when /^\(\?\:\\?(.)\|/
          char = $1
          return pattern unless encoded(char) == part
          Regexp.escape(char)
        else
          return pattern
        end
      end
      str.gsub /(.)([\.\+\(\)\/])/ do
        return pattern if $1 != "\\"
        $2
      end
    end

    private

    def encoded(char)
      return super if defined? super
      enc = URI.encode(char)
      enc = "(?:#{Regexp.escape enc}|#{URI.encode char, /./})" if enc == char
      enc = "(?:#{enc}|#{encoded('+')})" if char == " "
      enc
    end
  end

  register Decompile
end
