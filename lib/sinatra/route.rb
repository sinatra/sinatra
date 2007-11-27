class Sinatra::Route
      
  URI_CHAR = '[^/?:,&#]'.freeze unless defined?(URI_CHAR)
  PARAM = /:(#{URI_CHAR}+)/.freeze unless defined?(PARAM)
  
  attr_reader :block, :path
  
  def initialize(path, groups = :all, &b)
    @path, @groups, @block = path, Array(groups), b
    @param_keys = []
    @struct = Struct.new(:path, :groups, :block, :params, :default_status)
    regex = path.to_s.gsub(PARAM) do
      @param_keys << $1.intern
      "(#{URI_CHAR}+)"
    end
    if path =~ /:format$/
      @pattern = /^#{regex}$/
    else
      @param_keys << :format
      @pattern = /^#{regex}(?:\.(#{URI_CHAR}+))?$/
    end
  end
      
  def match(path)
    return nil unless path =~ @pattern
    params = @param_keys.zip($~.captures.compact.map(&:from_param)).to_hash
    @struct.new(@path, @groups, @block, include_format(params), 200)
  end
  
  def include_format(h)
    h.delete(:format) unless h[:format]
    Sinatra.config[:default_params].merge(h)
  end
  
  def pretty_print(pp)
    pp.text "{Route: #{@pattern} : [#{@param_keys.map(&:inspect).join(",")}] : #{@groups.join(",")} }"
  end
  
end
