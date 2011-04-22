require 'sinatra/base'

module Sinatra
  module Capture
    DUMMIES = {
      Tilt::HamlTemplate   => "!= capture_haml(*args, &block)",
      Tilt::ERBTemplate    => "<% yield(*args) %>",
      Tilt::ErubisTemplate => "<%= yield(*args) %>",
      :slim                => "== yield(*args)"
    }

    def call!(env)
      @current_engine = :ruby
      super
    end

    def capture(options = {}, &block)
      opts   = { :block  => block, :args => [] }.merge options
      engine = opts.delete(:engine)  || @current_engine
      block  = opts[:block]
      if engine == :ruby
        block[*opts[:args]]
      else
        dummy = DUMMIES[Tilt[engine]] || DUMMIES.fetch(engine)
        eval '_buf.clear if defined? _buf', block.binding
        render(engine, dummy, {}, opts, &block)
      end
    end

    def capture_later(options = {}, &block)
      opts = { :block => block, :args => [], :engine => @current_engine }
      opts.merge options
    end

    private

    def render(engine, *)
      @current_engine, engine_was = engine.to_sym, @current_engine
      super
    ensure
      @current_engine = engine_was
    end
  end

  helpers Capture
end
