class Error
  
  attr_reader :block
  
  def initialize(code, &b)
    @code, @block = code, b
  end
  
  def default_status
    @code
  end
  
  def params; {}; end
  
  def groups; []; end

end
