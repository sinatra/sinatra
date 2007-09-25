module Sinatra
  
  module Haml
    
    module InstanceMethods
      
      def haml(content)
        require 'haml' 
        body ::Haml::Engine.new(determine_template(content, :haml)).render(self)
      end
      
    end
    
  end
  
end
