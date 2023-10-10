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
  #   hash = Sinatra::IndifferentHash.new
  #   hash[:a] = 1
  #
  # You are guaranteed that the key is returned as a string:
  #
  #   hash.keys # => ["a"]
  #
  # Technically other types of keys are accepted:
  #
  #   hash = Sinatra::IndifferentHash
  #   hash[:a] = 1
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
      args.map!(&method(:convert_value))

      super(*args)
    end

    def default(*args)
      args.map!(&method(:convert_key))

      super(*args)
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
      args.map!(&method(:convert_value))

      super(convert_key(key), *args)
    end

    def [](key)
      super(convert_key(key))
    end

    def []=(key, value)
      super(convert_key(key), convert_value(value))
    end

    alias store []=

    def key(value)
      super(convert_value(value))
    end

    def key?(key)
      super(convert_key(key))
    end

    alias has_key? key?
    alias include? key?
    alias member? key?

    def value?(value)
      super(convert_value(value))
    end

    alias has_value? value?

    def delete(key)
      super(convert_key(key))
    end

    # Added in Ruby 2.3
    def dig(key, *other_keys)
      super(convert_key(key), *other_keys)
    end

    def fetch_values(*keys)
      keys.map!(&method(:convert_key))

      super(*keys)
    end

    def slice(*keys)
      keys.map!(&method(:convert_key))

      self.class[super(*keys)]
    end

    def values_at(*keys)
      keys.map!(&method(:convert_key))

      super(*keys)
    end

    def merge!(*other_hashes)
      other_hashes.each do |other_hash|
        if other_hash.is_a?(self.class)
          super(other_hash)
        else
          other_hash.each_pair do |key, value|
            key = convert_key(key)
            value = yield(key, self[key], value) if block_given? && key?(key)
            self[key] = convert_value(value)
          end
        end
      end

      self
    end

    alias update merge!

    def merge(*other_hashes, &block)
      dup.merge!(*other_hashes, &block)
    end

    def replace(other_hash)
      super(other_hash.is_a?(self.class) ? other_hash : self.class[other_hash])
    end

    def transform_values(&block)
      dup.transform_values!(&block)
    end

    def transform_values!
      super
      super(&method(:convert_value))
    end

    def transform_keys(&block)
      dup.transform_keys!(&block)
    end

    def transform_keys!
      super
      super(&method(:convert_key))
    end

    def select(*args, &block)
      return to_enum(:select) unless block_given?

      dup.tap { |hash| hash.select!(*args, &block) }
    end

    def reject(*args, &block)
      return to_enum(:reject) unless block_given?

      dup.tap { |hash| hash.reject!(*args, &block) }
    end

    def compact
      dup.tap(&:compact!)
    end

    def except(*keys)
      keys.map!(&method(:convert_key))

      super(*keys)
    end if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("3.0")

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
