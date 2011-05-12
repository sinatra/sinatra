require 'sinatra/base'
require 'sinatra/engine_tracking'
require 'backports'

module Sinatra
  module Capture
    include Sinatra::EngineTracking

    DUMMIES = {
      :haml => "!= capture_haml(*args, &block)",
      :erb  => "<% @capture = yield(*args) %>",
      :slim => "== yield(*args)"
    }

    DUMMIES[:erubis] = DUMMIES[:erb]

    def capture(*args, &block)
      @capture = nil
      if current_engine == :ruby
        result = block[*args]
      else
        buffer     = eval '_buf if defined?(_buf)', block.binding
        old_buffer = buffer.dup if buffer
        dummy      = DUMMIES.fetch(current_engine)
        options    = { :layout => false, :locals => {:args => args, :block => block }}

        buffer.try :clear
        result = render(current_engine, dummy, options, &block)
      end
      result.strip.empty? && @capture ? @capture : result
    ensure
      buffer.try :replace, old_buffer
    end

    def capture_later(&block)
      engine = current_engine
      proc { |*a| with_engine(engine) { @capture = capture(*a, &block) }}
    end
  end

  helpers Capture
end
