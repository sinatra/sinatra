# frozen_string_literal: true

require 'forwardable'

module SpecHelpers
  extend Forwardable
  def_delegators :last_response, :body, :headers, :status, :errors
  def_delegators :current_session, :env_for
  attr_writer :app

  def app
    @app ||= nil
    @app || mock_app(DummyApp)
  end

  def mock_app(app = nil, lint: true, &block)
    app = block if app.nil? && (block.arity == 1)
    if app
      klass = described_class
      mock_app do
        use Rack::Head
        use(Rack::Config) { |e| e['rack.session'] ||= {} }
        use klass
        run app
      end
    elsif lint
      @app = Rack::Lint.new Rack::Builder.new(&block).to_app
    else
      @app = Rack::Builder.new(&block).to_app
    end
  end

  def with_headers(headers)
    proc { [200, { 'content-type' => 'text/plain' }.merge(headers), ['ok']] }
  end

  def env
    Thread.current[:last_env]
  end
end
