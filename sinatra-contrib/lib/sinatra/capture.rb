require 'sinatra/base'
require 'sinatra/engine_tracking'
require 'backports'

module Sinatra
  #
  # = Sinatra::Capture
  #
  # This extension enables adding blocks inside your templates.
  # It currently works for erb, slim and haml.
  #
  # Example:
  #
  #    # in hello_world.erb
  #
  #    Say
  #    <% a = capture do %>World<% end %>
  #    Hello <%= a %>!
  #
  #    # in hello_world.slim
  #
  #    | Say
  #    - a = capture do
  #      | World
  #      | Hello #{a.strip}!
  #
  #    # in hello_world.haml
  #
  #    Say
  #    - a = capture do
  #      World
  #      Hello #{a.strip}!
  #
  #
  # You can also use nested blocks.
  #
  # Example
  #
  #     # in hello_world.erb
  #
  #     Say
  #     <% a = capture do %>
  #       <% b = capture do %>World<% end %>
  #         <%= b %>!
  #     <% end %>
  #     Hello <%= a.strip %>
  #
  #     # in hello_world.slim
  #
  #     | Say
  #     - a = capture do
  #       - b = capture do
  #         | World
  #       | #{b.strip}!
  #     | Hello #{a.strip}
  #
  #     # in hello_world.haml
  #
  #     Say
  #     - a = capture do
  #       - b = capture do
  #         World
  #       #{b.strip}!
  #     Hello #{a.strip}
  #
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
