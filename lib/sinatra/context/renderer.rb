Layouts = Hash.new # :nodoc:

module Sinatra

  # The magic or rendering happens here.  This is included in Sinatra::EventContext on load.
  # 
  # These methods are the foundation for Sinatra::Erb and Sinatra::Haml and allow you to quickly
  # create custom wrappers for your favorite rendering engines outside of erb and haml.

  module Renderer
    
    DEFAULT_OPTIONS = {
      :views_directory => 'views',
      :layout => :layout
    }
                

    # Renders templates from a string or file and handles their layouts:
    #
    # Example:
    #   module MyRenderer
    #     def my(template, options, &layout)
    #       render(template, :my, options, &layout)
    #     end
    #     
    #     def render_my(template)
    #       template.capitalize  # It capitalizes templates!!!!!  WOW!
    #     end
    #   end
    #   Sinatra::EventContext.send :include, MyRenderer
    # 
    #   get '/' do
    #      my "something"
    #   end
    # 
    #   get_it '/' # => 'Something'
    # 
    # The second method is named render_extname.  render will call this dynamicly
    # 
    # paramaters:
    # * +template+  If String, renders the string.  If Symbol, reads from file with the basename of the Symbol; uses +renderer+ for extension.
    # * +renderer+  A symbol defining the render_ method to call and the extension append to +template+ when looking in the +views_directory+
    # * +options+   An optional Hash of options (see next section)
    # 
    # options:
    # * +:views_directory+ Allows you to override the default 'views' directory an look for the template in another
    # * +:layout+          Which layout to use (see Sinatra::Dsl).  false to force a render with no layout.  Defaults to :default layout
    #
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
