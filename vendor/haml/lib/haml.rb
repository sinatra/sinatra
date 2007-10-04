module Sinatra
  
  module Haml # :nodoc:
    
    module EventContext
      
      # Renders raw haml in within the events context.
      #
      # This can be use to if you already have the template on hand and don't
      # need a layout.  This is speedier than using haml
      #
      def render_haml(template)
        require 'haml'
        body ::Haml::Engine.new(template).render(self)
      end
      
      # Renders Haml within an event.
      # 
      # Inline example:
      # 
      #   get '/foo' do
      #     haml '== The time is #{Time.now}'
      #   end
      #
      # Template example:
      #
      #   get '/foo' do
      #     haml :foo  #=> reads and renders view/foo.haml
      #   end
      # 
      # For options, see Sinatra::Renderer
      #
      # See also:  Sinatra::Renderer
      def haml(template, options = {}, &layout)
        render(template, :haml, options, &layout)
      end
    end
    
  end
  
end
