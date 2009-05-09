ENV['RACK_ENV'] = 'test'

begin
  require 'rack'
rescue LoadError
  require 'rubygems'
  require 'rack'
end

require 'contest'
require 'sinatra/test'
require 'haml'

begin
  require 'redgreen'
rescue LoadError
end

require File.dirname(__FILE__) + '/../lib/sinatra/content_for'

Sinatra::Base.set :environment, :test

module Sinatra
  class Base
    set :environment, :test
    helpers ContentFor
  end
end

class Test::Unit::TestCase
  include Sinatra::Test

  class << self
    alias_method :it, :test
  end

  def mock_app(base=Sinatra::Base, &block)
    @app = Sinatra.new(base, &block)
  end
end

class ContentForTest < Test::Unit::TestCase
  context 'using erb' do
    def erb_app(view)
      mock_app {
        layout { '<% yield_content :foo %>' }
        get('/') { erb view } 
      }
    end

    it 'renders blocks declared with the same key you use when rendering' do
      erb_app '<% content_for :foo do %>foo<% end %>'

      get '/'
      assert ok?
      assert_equal 'foo', body
    end

    it 'does not render a block with a different key' do
      erb_app '<% content_for :bar do %>bar<% end %>'

      get '/'
      assert ok?
      assert_equal '', body
    end

    it 'renders multiple blocks with the same key' do
      erb_app <<-erb_snippet
        <% content_for :foo do %>foo<% end %>
        <% content_for :foo do %>bar<% end %>
        <% content_for :baz do %>WON'T RENDER ME<% end %>
        <% content_for :foo do %>baz<% end %>
      erb_snippet

      get '/'
      assert ok?
      assert_equal 'foobarbaz', body
    end

    it 'passes values to the blocks' do
      mock_app {
        layout { '<% yield_content :foo, 1, 2 %>' }
        get('/') { erb '<% content_for :foo do |a, b| %><i><%= a %></i> <%= b %><% end %>' }
      }

      get '/'
      assert ok?
      assert_equal '<i>1</i> 2', body
    end
  end

  context 'with haml' do
    def haml_app(view)
      mock_app {
        layout { '= yield_content :foo' }
        get('/') { haml view } 
      }
    end

    it 'renders blocks declared with the same key you use when rendering' do
      haml_app <<-haml_end
- content_for :foo do
  foo
haml_end

      get '/'
      assert ok?
      assert_equal "foo\n", body
    end

    it 'does not render a block with a different key' do
      haml_app <<-haml_end
- content_for :bar do
  bar
haml_end

      get '/'
      assert ok?
      assert_equal "\n", body
    end

    it 'renders multiple blocks with the same key' do
      haml_app <<-haml_end
- content_for :foo do
  foo
- content_for :foo do
  bar
- content_for :baz do
  WON'T RENDER ME
- content_for :foo do
  baz
haml_end

      get '/'
      assert ok?
      assert_equal "foo\nbar\nbaz\n", body
    end

    it 'passes values to the blocks' do
      mock_app {
        layout { '= yield_content :foo, 1, 2' }
        get('/') { 
          haml <<-haml_end
- content_for :foo do |a, b|
  %i= a
  =b
haml_end
        }
      }

      get '/'
      assert ok?
      assert_equal "<i>1</i>\n2\n", body
    end
  end
end
