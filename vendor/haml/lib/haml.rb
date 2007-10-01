module Sinatra
  
  module Haml
    
    module EventContext
      
      def render_haml(content)
        require 'haml'
        body ::Haml::Engine.new(content).render(self)
      end
      
      def haml(template, options = {}, &layout)
        render(template, :haml, options, &layout)
      end
    end
    
  end
  
end
