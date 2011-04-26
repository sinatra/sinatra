require 'sinatra/base'
require 'sinatra/engine_tracking'
require 'backports'

module Sinatra
  module Capture
    include Sinatra::EngineTracking

    DUMMIES = {
      Tilt::HamlTemplate   => "!= capture_haml(*args, &block)",
      Tilt::ERBTemplate    => "<% @capture = yield(*args) %>",
      Tilt::ErubisTemplate => "<%= yield(*args) %>",
      :slim                => "== yield(*args)"
    }

    def capture(*args, &block)
      if current_engine == :ruby
        block[*args]
      else
        eval '_buf.try(:clear) if defined? _buf', block.binding
        dummy    = DUMMIES[Tilt[current_engine]] || DUMMIES.fetch(current_engine)
        @capture = nil
        result   = render(current_engine, dummy, {}, {:args => args, :block => block}, &block)
        result   = @capture if result.strip.empty? and @capture
        result
      end
    end

    def capture_later(&block)
      engine = current_engine
      proc { |*a| with_engine(engine) { @capture = capture(*a, &block) }}
    end
  end

  helpers Capture
end
