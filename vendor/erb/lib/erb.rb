module Sinatra
  
  module Erb
    
    module EventContext
      
      def render_erb(content)
        require 'erb'
        body ERB.new(content).result(binding)
      end
      
      def erb(template, options = {}, &layout)
        render(template, :erb, options, &layout)
      end
    end
    
  end
  
end
