Layouts = Hash.new

module Sinatra

  module Renderer
    
    DEFAULT_OPTIONS = {
      :views_directory => 'views',
      :layout => :layout
    }
                
    def render(template, renderer, options = {})
      options = DEFAULT_OPTIONS.merge(options)
      
      layout = block_given? ? yield : Layouts[options[:layout]]
      
      result_method = 'render_%s' % renderer
      
      if layout
        send(result_method, layout) { send(result_method, determine_template(template, renderer, options)) }
      else
        send(result_method, determine_template(template, renderer, options))
      end
    end
    
    protected
    
      def determine_template(template, ext, options)
        if template.is_a?(Symbol)
          File.read("%s/%s.%s" % [options[:views_directory], template, ext])
        else
          template
        end
      end
      
  end
  
end
