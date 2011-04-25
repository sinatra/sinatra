require 'sinatra/base'
require 'sinatra/engine_tracking'

module Sinatra
  module Capture
    include Sinatra::EngineTracking

    DUMMIES = {
      Tilt::HamlTemplate   => "!= capture_haml(*args, &block)",
      Tilt::ERBTemplate    => "<% yield(*args) %>",
      Tilt::ErubisTemplate => "<%= yield(*args) %>",
      :slim                => "== yield(*args)"
    }

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
  end

  helpers Capture
end
