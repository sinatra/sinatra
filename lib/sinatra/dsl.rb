module Kernel

  %w( get post put delete ).each do |verb|
    eval <<-end_eval
      def #{verb}(path, &block)
        Sinatra::Event.new(:#{verb}, path, &block)
      end
    end_eval
  end
  
  def after_attend(filter_name = nil, &block)
    Sinatra::Event.after_attend(filter_name, &block)
  end
  
  def helpers(&block)
    Sinatra::EventContext.class_eval(&block)
  end

  def static(path, root)
    Sinatra::StaticEvent.new(path, root)
  end
    
  %w(test development production).each do |env|
    module_eval <<-end_eval
      def #{env}
        yield if Sinatra::Options.environment == :#{env}
      end
    end_eval
  end
  
end
