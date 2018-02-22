# frozen_string_literal: true
module Sinatra
  # A poor man's ActiveSupport::HashWithIndifferentAccess, with all the Rails-y
  # stuff removed.
  #
  # Implements a hash where keys <tt>:foo</tt> and <tt>"foo"</tt> are
  # considered to be the same.
  #
  #   rgb = Sinatra::IndifferentHash.new
  #
  #   rgb[:black]    =  '#000000' # symbol assignment
  #   rgb[:black]  # => '#000000' # symbol retrieval
  #   rgb['black'] # => '#000000' # string retrieval
  #
  #   rgb['white']   =  '#FFFFFF' # string assignment
  #   rgb[:white]  # => '#FFFFFF' # symbol retrieval
  #   rgb['white'] # => '#FFFFFF' # string retrieval
  #
  # Internally, symbols are mapped to strings when used as keys in the entire
  # writing interface (calling e.g. <tt>[]=</tt>, <tt>merge</tt>). This mapping
  # belongs to the public interface. For example, given:
  #
  #   hash = Sinatra::IndifferentHash.new(:a=>1)
  #
  # You are guaranteed that the key is returned as a string:
  #
  #   hash.keys # => ["a"]
  #
  # Technically other types of keys are accepted:
  #
  #   hash = Sinatra::IndifferentHash.new(:a=>1)
  #   hash[0] = 0
  #   hash # => { "a"=>1, 0=>0 }
  #
  # But this class is intended for use cases where strings or symbols are the
  # expected keys and it is convenient to understand both as the same. For
  # example the +params+ hash in Sinatra.
  class IndifferentHash < Hash
    def self.[](*args)
      new.merge!(Hash[*args])
    end

    def initialize(*args)
      super(*args.map(&method(:convert_value)))
    end

    def default(*args)
      super(*args.map(&method(:convert_key)))
    end

    def default=(value)
      super(convert_value(value))
    end

    def assoc(key)
      super(convert_key(key))
    end

    def rassoc(value)
      super(convert_value(value))
    end

    def fetch(key, *args)
      super(convert_key(key), *args.map(&method(:convert_value)))
    end

    def [](key)
      super(convert_key(key))
    end

    def []=(key, value)
      super(convert_key(key), convert_value(value))
    end

    alias_method :store, :[]=

    def key(value)
      super(convert_value(value))
    end

    def key?(key)
      super(convert_key(key))
    end

    alias_method :has_key?, :key?
    alias_method :include?, :key?
    alias_method :member?, :key?

    def value?(value)
      super(convert_value(value))
    end

    alias_method :has_value?, :value?

    def delete(key)
      super(convert_key(key))
    end

    def dig(key, *other_keys)
      super(convert_key(key), *other_keys)
    end if method_defined?(:dig) # Added in Ruby 2.3

    def fetch_values(*keys)
      super(*keys.map(&method(:convert_key)))
    end if method_defined?(:fetch_values) # Added in Ruby 2.3

    def slice(*keys)
      keys.map!(&method(:convert_key))
      self.class[super(*keys)]
    end if method_defined?(:slice) # Added in Ruby 2.5

    def values_at(*keys)
      super(*keys.map(&method(:convert_key)))
    end

    def merge!(other_hash)
      return super if other_hash.is_a?(self.class)

      other_hash.each_pair do |key, value|
        key = convert_key(key)
        value = yield(key, self[key], value) if block_given? && key?(key)
        self[key] = convert_value(value)
      end

      self
    end

    alias_method :update, :merge!

    def merge(other_hash, &block)
      dup.merge!(other_hash, &block)
    end

    def replace(other_hash)
      super(other_hash.is_a?(self.class) ? other_hash : self.class[other_hash])
    end

    private

    def convert_key(key)
      key.is_a?(Symbol) ? key.to_s : key
    end

    def convert_value(value)
      case value
      when Hash
        value.is_a?(self.class) ? value : self.class[value]
      when Array
        value.map(&method(:convert_value))
      else
        value
      end
    end
  end
end
