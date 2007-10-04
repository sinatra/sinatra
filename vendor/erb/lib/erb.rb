module Sinatra
  
  module Erb # :nodoc:
    
    module EventContext
      
      # Renders raw erb in within the events context.
      #
      # This can be use to if you already have the template on hand and don't
      # need a layout.  This is speedier than using erb
      #
      def render_erb(content)
        require 'erb'
        body ERB.new(content).result(binding)
      end

      # Renders erb within an event.
      # 
      # Inline example:
      # 
      #   get '/foo' do
      #     erb 'The time is <%= Time.now %>'
      #   end
      #
      # Template example:
      #
      #   get '/foo' do
      #     erb :foo  #=> reads and renders view/foo.erb
      #   end
      # 
      # For options, see Sinatra::Renderer
      #
      # See also:  Sinatra::Renderer
      def erb(template, options = {}, &layout)
        render(template, :erb, options, &layout)
      end
    end
    
  end
  
end
