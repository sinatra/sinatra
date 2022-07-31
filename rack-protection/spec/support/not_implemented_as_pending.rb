# frozen_string_literal: true

# see http://blog.101ideas.cz/posts/pending-examples-via-not-implemented-error-in-rspec.html
module NotImplementedAsPending
  def self.included(base)
    base.class_eval do
      alias_method :__finish__, :finish
      remove_method :finish
    end
  end

  def finish(reporter)
    if @exception.is_a?(NotImplementedError)
      from = @exception.backtrace[0]
      message = "#{@exception.message} (from #{from})"
      @pending_declared_in_example = message
      metadata[:pending] = true
      @exception = nil
    end

    __finish__(reporter)
  end

  RSpec::Core::Example.send :include, self
end
