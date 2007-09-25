module Sinatra
  
  module Erb
    
    module InstanceMethods
      
      def erb(content)
        require 'erb'
        body ERB.new(determine_template(content, :erb)).result(binding)
      end
      
    end
    
  end
  
end
