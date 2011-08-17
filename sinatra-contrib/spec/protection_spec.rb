require 'backports'
require_relative 'spec_helper'

class MiddlewareTracker < Rack::Builder
  def self.used
    @used ||= []
  end

  def use(middleware, *)
    MiddlewareTracker.used << middleware
    super
  end
end

describe Sinatra::Protection do
  before do
    Rack.send :remove_const, :Builder
    Rack.const_set :Builder, MiddlewareTracker
    MiddlewareTracker.used.clear
  end

  after do
    Rack.send :remove_const, :Builder
    Rack.const_set :Builder, MiddlewareTracker.superclass
  end

  it 'sets up Rack::Protection' do
    Sinatra.new { register Sinatra::Protection }.new
    MiddlewareTracker.used.should include(Rack::Protection)
  end

  it 'sets up Rack::Protection::PathTraversal by default' do
    Sinatra.new { register Sinatra::Protection }.new
    MiddlewareTracker.used.should include(Rack::Protection::PathTraversal)
  end


  it 'does not set up Rack::Protection::PathTraversal when disabling it' do
    Sinatra.new do
      register Sinatra::Protection
      set :protection, :except => :path_traversal
    end.new
    MiddlewareTracker.used.should_not include(Rack::Protection::PathTraversal)
  end
end
