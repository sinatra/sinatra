class Module
  def attr_with_default(sym, default)
    define_method "#{sym}=" do |obj|
      instance_variable_set("@#{sym}", obj)
    end

    define_method sym do 
      instance_variable_get("@#{sym}") || default
    end
  end
end
