
module Sinatra

  module Dsl

    # Define an Event that responds to a +path+ on GET method
    # 
    # The +path+ can be a template (i.e. '/:foo/bar/:baz').  When recognized, it will add <tt>:foo</tt> and <tt>:baz</tt> to +params+ with their values.
    #
    # Example:
    #   # Going RESTful
    #
    #   get '/' do
    #     .. show stuff ..
    #   end
    #   
    #   post '/' do
    #     .. add stuff ..
    #     redirect '/'
    #   end
    #   
    #   put '/:id' do
    #     .. update params[:id] ..
    #     redirect '/'
    #   end
    #   
    #   delete '/:id' do
    #     .. delete params[:id] ..
    #     redirect '/'
    #   end
    #
    # BIG NOTE: PUT and DELETE are trigged when POSTing to their paths with a <tt>_method</tt> param whose value is PUT or DELETE
    #
    def get(path, &block)
      Sinatra::Event.new(:get, path, &block)
    end

    # Same as get but responds to POST
    def post(path, &block)
      Sinatra::Event.new(:post, path, &block)
    end

    # Same as get but responds to PUT
    #
    # BIG NOTE: PUT and DELETE are trigged when POSTing to their paths with a <tt>_method</tt> param whose value is PUT or DELETE
    def put(path, &block)
      Sinatra::Event.new(:put, path, &block)
    end

    # Same as get but responds to DELETE
    #
    # BIG NOTE: PUT and DELETE are trigged when POSTing to their paths with a <tt>_method</tt> param whose value is PUT or DELETE
    def delete(path, &block)
      Sinatra::Event.new(:delete, path, &block)
    end

    # Run given block after each Event's execution
    # Usage:
    #   before_attend do
    #     logger.debug "After event attend!"
    #   end
    # or
    #   before_attend :authorize # authorize is a helper method defined using helpers
    #
    # Stop execution using - throw :halt
    #   before_attend do
    #     throw :halt, 401 unless has_access?
    #   end
    # Throw a Symbol to execute a helper method
    # Throw a String to render it as the content
    # Throw a Fixnum to set the status
    #
    def before_attend(filter_name = nil, &block)
      Sinatra::Event.before_attend(filter_name, &block)
    end

    # Run given block after each Event's execution
    # Example:
    #   after_attend do
    #     logger.debug "After event attend!"
    #   end
    # or 
    #   after_attend :clean_up  # clean_up is a helper method defined using helpers
    #
    def after_attend(filter_name = nil, &block)
      Sinatra::Event.after_attend(filter_name, &block)
    end
  
    # Add methods to each event for use during execution
    #
    # Example:
    #   helpers do
    #     def foo
    #       'foo!'
    #     end
    #   end
    #   
    #   get '/bar' do
    #     foo
    #   end
    #   
    #   get_it '/bar' # => 'foo!'
    #
    def helpers(&block)
      Sinatra::EventContext.class_eval(&block)
    end

    # Maps a path to a physical directory containing static files
    #
    # Example:
    #   static '/p', 'public'
    #
    def static(path, root)
      Sinatra::StaticEvent.new(path, root)
    end
    
    # Execute block if in environment is equal to env (Used for configuration)
    def config_for(env = :development)
      yield if Sinatra::Options.environment == env.to_sym
    end
    
    # Define named layouts (default name is <tt>:layout</tt>)
    # 
    # Examples:
    #   # Default layout in Erb
    #   layout do
    #     '-- <%= yield %> --'
    #   end
    #   
    #   # Named layout in Haml
    #   layout :for_haml do
    #     '== XXXX #{yield} XXXX'
    #   end
    #   
    #   # Loads layout named <tt>:"foo.erb"</tt> from file (default behaviour if block is omitted)
    #   layout 'foo.erb' # looks for foo.erb.  This is odd an is being re-thought
    #   
    #   def layout(name = :layout, options = {})
    #     Layouts[name] = unless block_given?
    #       File.read("%s/%s" % [options[:views_directory] || 'views', name])
    #     else
    #       yield
    #     end
    #   end
    #
    # Cool trick:
    #   
    #   # Send a one-time layout to renderer method
    #   get '/cooltrick' do
    #     erb 'wicked' do
    #       'Cool <%= yield %> Trick'
    #     end
    #   end
    #   
    #   get_it '/cooltrick' # => 'Cool wicked Trick'
    #
    def layout(name = :layout, options = {})
      Layouts[name] = unless block_given?
        File.read("%s/%s" % [options[:views_directory] || 'views', name])
      else
        yield
      end
    end  
  
    # Turn sessions <tt>:on</tt> or <tt>:off</tt>
    #  
    # NOTE:  There is currently no way to turn it on or off per Event... patches anyone?)
    def sessions(on_off)
      Sinatra::Session::Cookie.use = on_off
    end

  end

end

include Sinatra::Dsl
