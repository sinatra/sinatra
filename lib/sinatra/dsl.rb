module Kernel

  %w( get post put delete ).each do |verb|
    eval <<-end_eval
      def #{verb}(path, &block)
        Sinatra::Event.new(:#{verb}, path, &block)
      end
    end_eval
  end

end
