module Sinatra
  module Contrib
    def self.version
      VERSION
    end

    SIGNATURE = [1, 4, 7]
    VERSION   = SIGNATURE.join('.')

    VERSION.extend Comparable
    def VERSION.<=>(other)
      other = other.split('.').map { |i| i.to_i } if other.respond_to? :split
      SIGNATURE <=> Array(other)
    end
  end
end

