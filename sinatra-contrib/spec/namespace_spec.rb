require 'backports'
require_relative 'spec_helper'

describe Sinatra::Namespace do
  verbs = [:get, :head, :post, :put, :delete, :options]
  verbs << :patch if Sinatra::VERSION >= '1.3'

  def mock_app(&block)
    super do
      register Sinatra::Namespace
      class_eval(&block)
    end
  end

  def namespace(*args, &block)
    mock_app { namespace(*args, &block) }
  end

  verbs.each do |verb|
    describe "HTTP #{verb.to_s.upcase}" do
      describe 'pattern generation' do
        it "should add routes including prefix to the base app" do
          namespace("/foo") { send(verb, "/bar") { "baz" }}
          send(verb, "/foo/bar").should be_ok
          body.should == "baz" unless verb == :head
          send(verb, "/foo/baz").should_not be_ok
        end

        it "should allows adding routes with no path" do
          namespace("/foo") { send(verb) { "bar" } }
          send(verb, "/foo").should be_ok
          body.should == "bar" unless verb == :head
        end

        it "allows unsing regular expressions" do
          namespace("/foo") { send(verb, /\/\d\d/) { "bar" }}
          send(verb, "/foo/12").should be_ok
          body.should == "bar" unless verb == :head
          send(verb, "/foo/123").should_not be_ok
        end

        it "allows using regular expressions for the prefix" do
          namespace(/\/\d\d/) { send(verb, /\/\d\d/) { "foo" }}
          send(verb, "/23/12").should be_ok
          body.should == "foo" unless verb == :head
          send(verb, "/123/12").should_not be_ok
        end

        it "sets params correctly from namespace" do
          namespace("/:foo") { send(verb, "/bar") { params[:foo] }}
          send(verb, "/foo/bar").should be_ok
          body.should == "foo" unless verb == :head
          send(verb, "/foo/baz").should_not be_ok
          send(verb, "/fox/bar").should be_ok
          body.should == "fox" unless verb == :head
        end
  
        it "sets params correctly from route" do
          namespace("/foo") { send(verb, "/:bar") { params[:bar] }}
          send(verb, "/foo/bar").should be_ok
          body.should == "bar" unless verb == :head
          send(verb, "/foo/baz").should be_ok
          body.should == "baz" unless verb == :head
        end

        it "allows splats to be combined from namespace and route" do
          namespace("/*") { send(verb, "/*") { params[:splat].join " - " }}
          send(verb, '/foo/bar').should be_ok
          body.should == "foo - bar" unless verb == :head
        end

        it "sets params correctly from namespace if simple regexp is used for route" do
          namespace("/:foo") { send(verb, %r{/bar}) { params[:foo] }}
          send(verb, "/foo/bar").should be_ok
          body.should == "foo" unless verb == :head
          send(verb, "/foo/baz").should_not be_ok
          send(verb, "/fox/bar").should be_ok
          body.should == "fox" unless verb == :head
        end

        it "sets params correctly from route if simple regexp is used for namespace" do
          namespace(%r{/foo}) { send(verb, "/:bar") { params[:bar] }}
          send(verb, "/foo/bar").should be_ok
          body.should == "bar" unless verb == :head
          send(verb, "/foo/baz").should be_ok
          body.should == "baz" unless verb == :head
        end

        it 'allows defining routes without a pattern' do
          namespace(%r{/foo}) { send(verb) { 'bar' } }
          send(verb, '/foo').should be_ok
          body.should == 'bar' unless verb == :head 
        end
      end

      describe 'conditions' do
        it 'allows using conditions for namespaces' do
          mock_app do
            namespace(:host_name => 'example.com') { send(verb) { 'yes' }}
            send(verb, '/') { 'no' }
          end
          send(verb, '/', {}, 'HTTP_HOST' => 'example.com')
          last_response.should be_ok
          body.should == 'yes' unless verb == :head
          send(verb, '/', {}, 'HTTP_HOST' => 'example.org')
          last_response.should be_ok
          body.should == 'no' unless verb == :head
        end

        it 'allows using conditions for before filters' do
          namespace '/foo' do
            before(:host_name => 'example.com') { @yes = "yes" }
            send(verb) { @yes || "no" }
          end
          send(verb, '/foo', {}, 'HTTP_HOST' => 'example.com')
          last_response.should be_ok
          body.should == 'yes' unless verb == :head
          send(verb, '/foo', {}, 'HTTP_HOST' => 'example.org')
          last_response.should be_ok
          body.should == 'no' unless verb == :head
        end

        it 'allows using conditions for after filters' do
          ran = false
          namespace '/foo' do
            before(:host_name => 'example.com') { ran = true }
            send(verb) { "ok" }
          end
          send(verb, '/foo', {}, 'HTTP_HOST' => 'example.org')
          ran.should be_false
          send(verb, '/foo', {}, 'HTTP_HOST' => 'example.com')
          ran.should be_true
        end

        it 'allows using conditions for routes' do
          namespace '/foo' do
            send(verb, :host_name => 'example.com') { "ok" }
          end
          send(verb, '/foo', {}, 'HTTP_HOST' => 'example.com').should be_ok
          send(verb, '/foo', {}, 'HTTP_HOST' => 'example.org').should_not be_ok
        end

        it 'allows using conditions for before filters and the namespace' do
          ran = false
          namespace '/', :provides => :txt do
            before(:host_name => 'example.com') { ran = true }
            send(verb) { "ok" }
          end
          send(verb, '/', {}, 'HTTP_HOST' => 'example.org', 'HTTP_ACCEPT' => 'text/plain')
          ran.should be_false
          send(verb, '/', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/html')
          ran.should be_false
          send(verb, '/', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/plain')
          ran.should be_true
        end

        it 'allows using conditions for routes and the namespace' do
          namespace '/foo', :host_name => 'example.com' do
            send(verb, :provides => :txt) { "ok" }
          end
          send(verb, '/foo', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/plain').should be_ok
          send(verb, '/foo', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/html').should_not be_ok
          send(verb, '/foo', {}, 'HTTP_HOST' => 'example.org', 'HTTP_ACCEPT' => 'text/plain').should_not be_ok
        end

        it 'allows combining conditions with a prefix for namespaces' do
          namespace '/', :host_name => 'example.com' do
            send(verb) { "ok" }
          end
          send(verb, '/', {}, 'HTTP_HOST' => 'example.com').should be_ok
          send(verb, '/', {}, 'HTTP_HOST' => 'example.org').should_not be_ok
        end

        it 'allows combining conditions with a prefix for before filters' do
          ran = false
          namespace :provides => :txt do
            before('/foo', :host_name => 'example.com') { ran = true }
            send(verb, '/*') { "ok" }
          end
          send(verb, '/foo', {}, 'HTTP_HOST' => 'example.org', 'HTTP_ACCEPT' => 'text/plain')
          ran.should be_false
          send(verb, '/foo', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/html')
          ran.should be_false
          send(verb, '/bar', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/plain')
          ran.should be_false
          send(verb, '/foo', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/plain')
          ran.should be_true
        end

        it 'allows combining conditions with a prefix for after filters' do
          ran = false
          namespace :provides => :txt do
            after('/foo', :host_name => 'example.com') { ran = true }
            send(verb, '/*') { "ok" }
          end
          send(verb, '/foo', {}, 'HTTP_HOST' => 'example.org', 'HTTP_ACCEPT' => 'text/plain')
          ran.should be_false
          send(verb, '/foo', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/html')
          ran.should be_false
          send(verb, '/bar', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/plain')
          ran.should be_false
          send(verb, '/foo', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/plain')
          ran.should be_true
        end

        it 'allows combining conditions with a prefix for routes' do
          namespace :host_name => 'example.com' do
            send(verb, '/foo', :provides => :txt) { "ok" }
          end
          send(verb, '/foo', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/plain').should be_ok
          send(verb, '/foo', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/html').should_not be_ok
          send(verb, '/foo', {}, 'HTTP_HOST' => 'example.org', 'HTTP_ACCEPT' => 'text/plain').should_not be_ok
        end

        it 'allows combining conditions with a prefix for filters and the namespace' do
          ran = false
          namespace '/f', :provides => :txt do
            before('oo', :host_name => 'example.com') { ran = true }
            send(verb, '/*') { "ok" }
          end
          send(verb, '/foo', {}, 'HTTP_HOST' => 'example.org', 'HTTP_ACCEPT' => 'text/plain')
          ran.should be_false
          send(verb, '/foo', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/html')
          ran.should be_false
          send(verb, '/far', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/plain')
          ran.should be_false
          send(verb, '/foo', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/plain')
          ran.should be_true
        end

        it 'allows combining conditions with a prefix for routes and the namespace' do
          namespace '/f', :host_name => 'example.com' do
            send(verb, 'oo', :provides => :txt) { "ok" }
          end
          send(verb, '/foo', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/plain').should be_ok
          send(verb, '/foo', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/html').should_not be_ok
          send(verb, '/foo', {}, 'HTTP_HOST' => 'example.org', 'HTTP_ACCEPT' => 'text/plain').should_not be_ok
        end
      end

      describe 'filters' do
        it 'should trigger before filters for namespaces' do
          ran = false
          namespace('/foo') { before { ran = true }}
          send(verb, '/foo')
          ran.should be_true
        end

        it 'should trigger after filters for namespaces' do
          ran = false
          namespace('/foo') { after { ran = true }}
          send(verb, '/foo')
          ran.should be_true
        end

        it 'should not trigger before filter for different namespaces' do
          ran = false
          namespace('/foo') { before { ran = true }}
          send(verb, '/fox')
          ran.should be_false
        end

        it 'should not trigger after filter for different namespaces' do
          ran = false
          namespace('/foo') { after { ran = true }}
          send(verb, '/fox')
          ran.should be_false
        end
      end

      describe 'helpers' do
        it "allows defining helpers with the helpers method" do
          namespace '/foo' do
            helpers do
              def magic
                42
              end
            end

            send verb, '/bar' do
              magic.to_s
            end
          end

          send(verb, '/foo/bar').should be_ok
          body.should == '42' unless verb == :head
        end

        it "allows defining helpers without the helpers method" do
          namespace '/foo' do
            def magic
              42
            end

            send verb, '/bar' do
              magic.to_s
            end
          end

          send(verb, '/foo/bar').should be_ok
          body.should == '42' unless verb == :head
        end

        it "allows using helper mixins with the helpers method" do
          mixin = Module.new do
            def magic
              42
            end
          end

          namespace '/foo' do
            helpers mixin
            send verb, '/bar' do
              magic.to_s
            end
          end

          send(verb, '/foo/bar').should be_ok
          body.should == '42' unless verb == :head
        end

        it "makes helpers defined inside a namespace not available to routes outside that namespace" do
          mock_app do
            namespace '/foo' do
              def magic
                42
              end

              send verb, '/bar' do
                magic.to_s
              end
            end

            send verb, '/' do
              magic.to_s
            end
          end

          proc { send verb, '/' }.should raise_error(NameError)
        end

        it "makes helper mixins used inside a namespace not available to routes outside that namespace" do
          mixin = Module.new do
            def magic
              42
            end
          end

          mock_app do
            namespace '/foo' do
              helpers mixin
              send verb, '/bar' do
                magic.to_s
              end
            end

            send verb, '/' do
              magic.to_s
            end
          end

          proc { send verb, '/' }.should raise_error(NameError)
        end

        it "allows accessing helpers defined outside the namespace" do
          mock_app do
            helpers do
              def magic
                42
              end
            end

            namespace '/foo' do
              send verb, '/bar' do
                magic.to_s
              end
            end
          end

          send(verb, '/foo/bar').should be_ok
          body.should == '42' unless verb == :head
        end

        it "allows calling super in helpers overwritten inside a namespace" do
          mock_app do
            helpers do
              def magic
                42
              end
            end

            namespace '/foo' do
              def magic
                super - 19
              end

              send verb, '/bar' do
                magic.to_s
              end
            end
          end

          send(verb, '/foo/bar').should be_ok
          body.should == '23' unless verb == :head
        end
      end

      describe 'nesting' do
        it 'routes to nested namespaces' do
          namespace '/foo' do
            namespace '/bar' do
              send(verb, '/baz') { 'OKAY!!11!'}
            end
          end

          send(verb, '/foo/bar/baz').should be_ok
          body.should == 'OKAY!!11!' unless verb == :head
        end

        it 'exposes helpers to nested namespaces' do
          namespace '/foo' do
            helpers do
              def magic
                42
              end
            end

            namespace '/bar' do
              send verb, '/baz' do
                magic.to_s
              end
            end
          end

          send(verb, '/foo/bar/baz').should be_ok
          body.should == '42' unless verb == :head
        end

        it 'does not use helpers of nested namespaces outside that namespace' do
          namespace '/foo' do
            namespace '/bar' do
              def magic
                42
              end

              send verb, '/baz' do
                magic.to_s
              end
            end

            send verb do
              magic.to_s
            end
          end

          proc { send verb, '/foo' }.should raise_error(NameError)
        end

        it 'sets params correctly' do
          namespace('/:a') { namespace('/:b') { send(verb) { params[:a] }}}
          send(verb, '/foo/bar').should be_ok
          body.should ==  'foo' unless verb == :head
        end
      end

      describe 'error handlers' do
        it "should allow custom error handlers with not found" do
          namespace('/de') do
            not_found { 'nicht gefunden' }
          end
          send(verb, '/foo').status.should == 404
          last_response.body.should_not    == 'nicht gefunden' unless verb == :head
          get('/en/foo').status.should     == 404
          last_response.body.should_not    == 'nicht gefunden' unless verb == :head
          get('/de/foo').status.should     == 404
          last_response.body.should        == 'nicht gefunden' unless verb == :head
        end

        it "should allow custom error handlers with error" do
          namespace('/de') do
            error(404) { 'nicht gefunden' }
          end
          send(verb, '/foo').status.should == 404
          last_response.body.should_not    == 'nicht gefunden' unless verb == :head
          get('/en/foo').status.should     == 404
          last_response.body.should_not    == 'nicht gefunden' unless verb == :head
          get('/de/foo').status.should     == 404
          last_response.body.should        == 'nicht gefunden' unless verb == :head
        end
      end

      describe 'templates' do
        it "allows using templates from the base" do
          mock_app do
            template(:foo) { 'hi' }
            send(verb, '/') { erb :foo }
            namespace '/foo' do
              send(verb) { erb :foo }
            end
          end

          if verb != :head
            send(verb, '/').body.should == "hi"
            send(verb, '/foo').body.should == "hi"
          end
        end

        it "allows to define nested templates" do
          mock_app do
            template(:foo) { 'hi' }
            send(verb, '/') { erb :foo }
            namespace '/foo' do
              template(:foo) { 'ho' }
              send(verb) { erb :foo }
            end
          end

          if verb != :head
            send(verb, '/').body.should == "hi"
            send(verb, '/foo').body.should == "ho"
          end
        end

        it "allows to define nested layouts" do
          mock_app do
            layout { 'Hello <%= yield %>!' }
            template(:foo) { 'World' }
            send(verb, '/') { erb :foo }
            namespace '/foo' do
              layout { 'Hi <%= yield %>!' }
              send(verb) { erb :foo }
            end
          end

          if verb != :head
            send(verb, '/').body.should == "Hello World!"
            send(verb, '/foo').body.should == "Hi World!"
          end
        end

        it "allows using templates from the base" do
          mock_app do
            layout { "he said: <%= yield %>" }
            template(:foo) { 'hi' }
            send(verb, '/') { erb :foo }
            namespace '/foo' do
              template(:foo) { 'ho' }
              send(verb) { erb :foo }
            end
          end

          if verb != :head
            send(verb, '/').body.should == "he said: hi"
            send(verb, '/foo').body.should == "he said: ho"
          end
        end

        it "allows setting a different views directory" do
          mock_app do
            set :views, File.expand_path('../namespace', __FILE__)
            send(verb, '/') { erb :foo }
            namespace('/foo') do
              set :views, File.expand_path('../namespace/nested', __FILE__)
              send(verb) { erb :foo }
            end
          end

          if verb != :head
            send(verb, '/').body.should == "hi\n"
            send(verb, '/foo').body.should == "ho\n"
          end
        end
      end

      describe 'extensions' do
        it 'allows read access to settings' do
          value = nil
          mock_app do
            set :foo, 42
            namespace '/foo' do
              value = foo
            end
          end
          value.should == 42
        end

        it 'allows registering extensions for a namespace only' do
          a = b = nil
          extension = Module.new { define_method(:views) { "CUSTOM!!!" } }
          mock_app do
            namespace '/' do
              register extension
              a = views
            end
            b = views
          end
          a.should == 'CUSTOM!!!'
          b.should_not == 'CUSTOM!!!'
        end

        it 'triggers route_added hook' do
          route = nil
          extension = Module.new
          extension.singleton_class.class_eval do
            define_method(:route_added) { |*r| route = r }
          end
          mock_app do
            namespace '/f' do
              register extension
              get('oo') { }
            end
            get('/bar') { }
          end
          route[1].should == '/foo'
        end

        it 'prevents changing app global settings' do
          proc { namespace('/') { set :foo, :bar }}.should raise_error
        end
      end
    end
  end
end
