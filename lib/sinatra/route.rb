module Sinatra

  class Route

    SYMBOL_FIND = /:[a-z_]+/.freeze
    PARENTHETICAL_SEGMENT_STRING = "([^\/.,;?]+)".freeze

    attr_reader :regex, :params

    def initialize(template)
      @template = template.to_s.strip
      @default_params = { :format => 'html' }
      @params = {}
      extract_keys
      genereate_route
    end
  
    def recognize(path)
      @params.clear
      
      param_values = path.match(@regex).captures.compact rescue nil
            
      if param_values
        keys = @keys.size < param_values.size ? @keys.concat([:format]) : @keys
        @params = @default_params.merge(@keys.zip(param_values).to_hash)
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
        if template =~ /\.:format$|\.([\w\d]+)$/
          @default_params[:format] = $1 if $1
        else
          template << '.:format'
        end
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