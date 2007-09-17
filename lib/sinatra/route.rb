module Sinatra

  class Route

    DEFAULT_PARAMS = { :format => 'html' }

    attr_reader :regex, :params

    SYMBOL_FIND = /:[a-z_]+/.freeze
    PARENTHETICAL_SEGMENT_STRING = "([^\/.,;?]+)".freeze

    def initialize(template)
      @template = template.to_s.strip
      @params = {}
      extract_keys
      genereate_route
    end
  
    def recognize(path)
      @params.clear
      
      param_values = path.match(@regex).captures.compact rescue nil
            
      if param_values
        keys = @keys.size < param_values.size ? @keys.concat([:format]) : @keys
        @params = DEFAULT_PARAMS.merge(@keys.zip(param_values).to_hash)
        true
      else
        false
      end
    end

    private
    
      def extract_keys
        @keys = @template.scan(SYMBOL_FIND).map { |raw| eval(raw) }
        @keys
      end

      def genereate_route_without_format
        template = @template.dup
        template.gsub!(/\.:format$/, '')
        to_regex_route(template)
      end

      def genereate_route_with_format
        template = @template.dup
        template << '.:format' unless template =~ /\.:format$/
        to_regex_route(template)
      end
  
      def to_regex_route(template)
        /^#{template.gsub(/\./, '\.').gsub(SYMBOL_FIND, PARENTHETICAL_SEGMENT_STRING)}$/        
      end

      def genereate_route
        @regex = Regexp.union(genereate_route_without_format, genereate_route_with_format)
      end

  end

end