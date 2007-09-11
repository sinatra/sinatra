module Sinatra

  class PrettyUrl
    attr_reader :path, :vars
    
    VALID_FORMATS = %w( xml html )
    
    def initialize(path)
      @path = path
      @param_keys = []
      @vars = {}
      @regex = create_regex_from_path(@path)
    end
    
    def matches?(path)
      !(path =~ @regex).nil?
    end
    
    def extract_params(path)
      if matches = path.to_s.scan(@regex).flatten
        @param_keys.each_with_index do |v, i|
          @vars[v] = matches[i]
        end
      end
      vars[:format] = extract_format(path)
      vars
    end
    
    private
    
      def extract_format(path)
        format = (path).split('.')[-1]
        VALID_FORMATS.include?(format) ? format : 'html'
      end
    
      def create_regex_from_path(path)
        path = path.dup
        path.gsub!(/:(\w+)/) { @param_keys << $1.intern; '([\w\d-]+)' }
        path.gsub!(/(\/\.)/) { "\#{$1}" }
        /^#{path}$/
      end
  end
  
end
