# frozen_string_literal: true

require 'sinatra/base'

module Sinatra
  # Adds methods like `haml?` that allow helper methods to check whether they
  # are called from within a template.
  module EngineTracking
    attr_reader :current_engine

    # @return [Boolean] Returns true if current engine is `:erb`.
    def erb?
      @current_engine == :erb
    end

    # Returns true if the current engine is `:erubi`, or `Tilt[:erb]` is set
    # to Tilt::ErubiTemplate.
    #
    # @return [Boolean] Returns true if current engine is `:erubi`.
    def erubi?
      @current_engine == :erubi or
        (erb? && Tilt[:erb] == Tilt::ErubiTemplate)
    end

    # @return [Boolean] Returns true if current engine is `:haml`.
    def haml?
      @current_engine == :haml
    end

    # @return [Boolean] Returns true if current engine is `:sass`.
    def sass?
      @current_engine == :sass
    end

    # @return [Boolean] Returns true if current engine is `:scss`.
    def scss?
      @current_engine == :scss
    end

    # @return [Boolean] Returns true if current engine is `:builder`.
    def builder?
      @current_engine == :builder
    end

    # @return [Boolean] Returns true if current engine is `:liquid`.
    def liquid?
      @current_engine == :liquid
    end

    # @return [Boolean] Returns true if current engine is `:markdown`.
    def markdown?
      @current_engine == :markdown
    end

    # @return [Boolean] Returns true if current engine is `:rdoc`.
    def rdoc?
      @current_engine == :rdoc
    end

    # @return [Boolean] Returns true if current engine is `:markaby`.
    def markaby?
      @current_engine == :markaby
    end

    # @return [Boolean] Returns true if current engine is `:nokogiri`.
    def nokogiri?
      @current_engine == :nokogiri
    end

    # @return [Boolean] Returns true if current engine is `:slim`.
    def slim?
      @current_engine == :slim
    end

    # @return [Boolean] Returns true if current engine is `:ruby`.
    def ruby?
      @current_engine == :ruby
    end

    def initialize(*)
      @current_engine = :ruby
      super
    end

    # @param engine [Symbol, String] Name of Engine to shift to.
    def with_engine(engine)
      engine_was = @current_engine
      @current_engine = engine.to_sym
      yield
    ensure
      @current_engine = engine_was
    end

    private

    def render(engine, *)
      with_engine(engine) { super }
    end
  end

  helpers EngineTracking
end
