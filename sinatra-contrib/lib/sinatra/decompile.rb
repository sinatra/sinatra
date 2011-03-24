require 'sinatra/base'
require 'backports'

module Sinatra
  ##
  # Can be used as extension or stand-alone:
  #
  #   Sinatra::Decompile.decompile(...)
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
      return pattern if str =~ /^[\.\+]/
      str.gsub! /\([^\(]*\)/ do |part|
        case part
        when '(.*?)'
          return pattern if keys.shift != 'splat'
          '*'
        when '([^\/?#]+)'
          return pattern if keys.empty?
          ":" << keys.shift
        else
          return pattern
        end
      end
      str.gsub /(.)([\.\+\(\)\/])/ do
        return pattern if $1 != "\\"
        $2
      end
    end
  end

  register Decompile
end
