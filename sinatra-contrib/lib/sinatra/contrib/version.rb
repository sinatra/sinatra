module Sinatra
  module Contrib
    def self.version
      VERSION
    end

    module VERSION
      extend Comparable

      MAJOR     = 1
      MINOR     = 3
      TINY      = 0
      SIGNATURE = [MAJOR, MINOR, TINY]
      STRING    = SIGNATURE.join '.'

      def self.major; MAJOR  end
      def self.minor; MINOR  end
      def self.tiny;  TINY   end
      def self.to_s;  STRING end

      def self.hash
        STRING.hash
      end

      def self.<=>(other)
        other = other.split('.').map { |i| i.to_i } if other.respond_to? :split
        SIGNATURE <=> Array(other)
      end

      def self.inspect
        STRING.inspect
      end

      def self.respond_to?(meth, *)
        return true if super
        meth.to_s !~ /^__|^to_str$/ and STRING.respond_to? meth
      end

      def self.method_missing(meth, *args, &block)
        return super unless STRING.respond_to?(meth)
        STRING.send(meth, *args, &block)
      end
    end
  end
end
