require 'spec_helper'

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

      it 'prefixes the path with the namespace' do
        namespace('/foo') { send(verb, '/bar') { 'baz' }}
        send(verb, '/foo/bar').should be_ok
        body.should == 'baz' unless verb == :head
        send(verb, '/foo/baz').should_not be_ok
      end

      context 'when namespace is a string' do
        it 'accepts routes with no path' do
          namespace('/foo') { send(verb) { 'bar' } }
          send(verb, '/foo').should be_ok
          body.should == 'bar' unless verb == :head
        end

        it 'accepts the path as a named parameter' do
          namespace('/foo') { send(verb, '/:bar') { params[:bar] }}
          send(verb, '/foo/bar').should be_ok
          body.should == 'bar' unless verb == :head
          send(verb, '/foo/baz').should be_ok
          body.should == 'baz' unless verb == :head
        end

        it 'accepts the path as a regular expression' do
          namespace('/foo') { send(verb, /\/\d\d/) { 'bar' }}
          send(verb, '/foo/12').should be_ok
          body.should eq 'bar' unless verb == :head
          send(verb, '/foo/123').should_not be_ok
        end
      end

      context 'when namespace is a named parameter' do
        it 'accepts routes with no path' do
          namespace('/:foo') { send(verb) { 'bar' } }
          send(verb, '/foo').should be_ok
          body.should == 'bar' unless verb == :head
        end

        it 'sets the parameter correctly' do
          namespace('/:foo') { send(verb, '/bar') { params[:foo] }}
          send(verb, '/foo/bar').should be_ok
          body.should == 'foo' unless verb == :head
          send(verb, '/fox/bar').should be_ok
          body.should == 'fox' unless verb == :head
          send(verb, '/foo/baz').should_not be_ok
        end

        it 'accepts the path as a named parameter' do
          namespace('/:foo') { send(verb, '/:bar') { params[:bar] }}
          send(verb, '/foo/bar').should be_ok
          body.should == 'bar' unless verb == :head
          send(verb, '/foo/baz').should be_ok
          body.should == 'baz' unless verb == :head
        end

        it 'accepts the path as regular expression' do
          namespace('/:foo') { send(verb, %r{/bar}) { params[:foo] }}
          send(verb, '/foo/bar').should be_ok
          body.should == 'foo' unless verb == :head
          send(verb, '/fox/bar').should be_ok
          body.should == 'fox' unless verb == :head
          send(verb, '/foo/baz').should_not be_ok
        end
      end

      context 'when namespace is a regular expression' do
        it 'accepts routes with no path' do
          namespace(%r{/foo}) { send(verb) { 'bar' } }
          send(verb, '/foo').should be_ok
          body.should == 'bar' unless verb == :head
        end

        it 'accepts the path as a named parameter' do
          namespace(%r{/foo}) { send(verb, '/:bar') { params[:bar] }}
          send(verb, '/foo/bar').should be_ok
          body.should == 'bar' unless verb == :head
          send(verb, '/foo/baz').should be_ok
          body.should == 'baz' unless verb == :head
        end

        it 'accepts the path as a regular expression' do
          namespace(/\/\d\d/) { send(verb, /\/\d\d/) { 'foo' }}
          send(verb, '/23/12').should be_ok
          body.should == 'foo' unless verb == :head
          send(verb, '/123/12').should_not be_ok
        end
      end

      context 'when namespace is a splat' do
        it 'accepts the path as a splat' do
          namespace('/*') { send(verb, '/*') { params[:splat].join ' - ' }}
          send(verb, '/foo/bar').should be_ok
          body.should == 'foo - bar' unless verb == :head
        end
      end

      describe 'before-filters' do
        specify 'are triggered' do
          ran = false
          namespace('/foo') { before { ran = true }}
          send(verb, '/foo')
          ran.should be true
        end

        specify 'are not triggered for a different namespace' do
          ran = false
          namespace('/foo') { before { ran = true }}
          send(verb, '/fox')
          ran.should be false
        end
      end

      describe 'after-filters' do
        specify 'are triggered' do
          ran = false
          namespace('/foo') { after { ran = true }}
          send(verb, '/foo')
          ran.should be true
        end

        specify 'are not triggered for a different namespace' do
          ran = false
          namespace('/foo') { after { ran = true }}
          send(verb, '/fox')
          ran.should be false
        end
      end

      describe 'conditions' do
        context 'when the namespace has no prefix' do
          specify 'are accepted in the namespace' do
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

          specify 'are accepted in the route definition' do
            namespace :host_name => 'example.com' do
              send(verb, '/foo', :provides => :txt) { 'ok' }
            end
            send(verb, '/foo', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/plain').should be_ok
            send(verb, '/foo', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/html').should_not be_ok
            send(verb, '/foo', {}, 'HTTP_HOST' => 'example.org', 'HTTP_ACCEPT' => 'text/plain').should_not be_ok
          end

          specify 'are accepted in the before-filter' do
            ran = false
            namespace :provides => :txt do
              before('/foo', :host_name => 'example.com') { ran = true }
              send(verb, '/*') { 'ok' }
            end
            send(verb, '/foo', {}, 'HTTP_HOST' => 'example.org', 'HTTP_ACCEPT' => 'text/plain')
            ran.should be false
            send(verb, '/foo', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/html')
            ran.should be false
            send(verb, '/bar', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/plain')
            ran.should be false
            send(verb, '/foo', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/plain')
            ran.should be true
          end

          specify 'are accepted in the after-filter' do
            ran = false
            namespace :provides => :txt do
              after('/foo', :host_name => 'example.com') { ran = true }
              send(verb, '/*') { 'ok' }
            end
            send(verb, '/foo', {}, 'HTTP_HOST' => 'example.org', 'HTTP_ACCEPT' => 'text/plain')
            ran.should be false
            send(verb, '/foo', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/html')
            ran.should be false
            send(verb, '/bar', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/plain')
            ran.should be false
            send(verb, '/foo', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/plain')
            ran.should be true
          end
        end

        context 'when the namespace is a string' do
          specify 'are accepted in the namespace' do
            namespace '/foo', :host_name => 'example.com' do
              send(verb) { 'ok' }
            end
            send(verb, '/foo', {}, 'HTTP_HOST' => 'example.com').should be_ok
            send(verb, '/foo', {}, 'HTTP_HOST' => 'example.org').should_not be_ok
          end

          specify 'are accepted in the before-filter' do
            namespace '/foo' do
              before(:host_name => 'example.com') { @yes = 'yes' }
              send(verb) { @yes || 'no' }
            end
            send(verb, '/foo', {}, 'HTTP_HOST' => 'example.com')
            last_response.should be_ok
            body.should == 'yes' unless verb == :head
            send(verb, '/foo', {}, 'HTTP_HOST' => 'example.org')
            last_response.should be_ok
            body.should == 'no' unless verb == :head
          end

          specify 'are accepted in the after-filter' do
            ran = false
            namespace '/foo' do
              before(:host_name => 'example.com') { ran = true }
              send(verb) { 'ok' }
            end
            send(verb, '/foo', {}, 'HTTP_HOST' => 'example.org')
            ran.should be false
            send(verb, '/foo', {}, 'HTTP_HOST' => 'example.com')
            ran.should be true
          end

          specify 'are accepted in the route definition' do
            namespace '/foo' do
              send(verb, :host_name => 'example.com') { 'ok' }
            end
            send(verb, '/foo', {}, 'HTTP_HOST' => 'example.com').should be_ok
            send(verb, '/foo', {}, 'HTTP_HOST' => 'example.org').should_not be_ok
          end

          context 'when the namespace has a condition' do
            specify 'are accepted in the before-filter' do
              ran = false
              namespace '/', :provides => :txt do
                before(:host_name => 'example.com') { ran = true }
                send(verb) { 'ok' }
              end
              send(verb, '/', {}, 'HTTP_HOST' => 'example.org', 'HTTP_ACCEPT' => 'text/plain')
              ran.should be false
              send(verb, '/', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/html')
              ran.should be false
              send(verb, '/', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/plain')
              ran.should be true
            end

            specify 'are accepted in the filters' do
              ran = false
              namespace '/f', :provides => :txt do
                before('oo', :host_name => 'example.com') { ran = true }
                send(verb, '/*') { 'ok' }
              end
              send(verb, '/foo', {}, 'HTTP_HOST' => 'example.org', 'HTTP_ACCEPT' => 'text/plain')
              ran.should be false
              send(verb, '/foo', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/html')
              ran.should be false
              send(verb, '/far', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/plain')
              ran.should be false
              send(verb, '/foo', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/plain')
              ran.should be true
            end
          end
        end
      end

      describe 'helpers' do
        it 'are defined using the helpers method' do
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

        it 'can be defined as normal methods' do
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

        it 'can be defined using module mixins' do
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

        specify 'are unavailable outside the namespace where they are defined' do
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

        specify 'are unavailable outside the namespace that they are mixed into' do
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

        specify 'are available to nested namespaces' do
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

        specify 'can call super from nested definitions' do
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

        specify 'does not provide access to nested helper methods' do
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

        it 'accepts a nested namespace as a named parameter' do
          namespace('/:a') { namespace('/:b') { send(verb) { params[:a] }}}
          send(verb, '/foo/bar').should be_ok
          body.should ==  'foo' unless verb == :head
        end
      end

      describe 'error handling' do
        it 'can be customized using the not_found block' do
          namespace('/de') do
            not_found { 'nicht gefunden' }
          end
          send(verb, '/foo').status.should eq 404
          last_response.body.should_not    eq 'nicht gefunden' unless verb == :head
          get('/en/foo').status.should     eq 404
          last_response.body.should_not    eq 'nicht gefunden' unless verb == :head
          get('/de/foo').status.should     eq 404
          last_response.body.should        eq 'nicht gefunden' unless verb == :head
        end

        it 'can be customized for specific error codes' do
          namespace('/de') do
            error(404) { 'nicht gefunden' }
          end
          send(verb, '/foo').status.should eq 404
          last_response.body.should_not    eq 'nicht gefunden' unless verb == :head
          get('/en/foo').status.should     eq 404
          last_response.body.should_not    eq 'nicht gefunden' unless verb == :head
          get('/de/foo').status.should     eq 404
          last_response.body.should        eq 'nicht gefunden' unless verb == :head
        end

        it 'falls back to the handler defined in the base app' do
          mock_app do
            error(404) { 'not found...' }
            namespace('/en') do
            end
            namespace('/de') do
              error(404) { 'nicht gefunden' }
            end
          end
          send(verb, '/foo').status.should eq 404
          last_response.body.should        eq 'not found...' unless verb == :head
          get('/en/foo').status.should     eq 404
          last_response.body.should        eq 'not found...' unless verb == :head
          get('/de/foo').status.should     eq 404
          last_response.body.should        eq 'nicht gefunden' unless verb == :head
        end

        it 'can be customized for specific Exception classes' do
          mock_app do
            class AError < StandardError; end
            class BError < AError; end

            error(AError) do
              body('auth failed')
              401
            end

            namespace('/en') do
              get '/foo' do
                raise BError
              end
            end

            namespace('/de') do
              error(AError) do
                body('methode nicht erlaubt')
                406
              end

              get '/foo' do
                raise BError
              end
            end
          end
          get('/en/foo').status.should     eq 401
          last_response.body.should        eq 'auth failed' unless verb == :head
          get('/de/foo').status.should     eq 406
          last_response.body.should        eq 'methode nicht erlaubt' unless verb == :head
        end

        it "allows custom error handlers when namespace is declared as /en/:id. Issue #119" do
          mock_app {
            class CError < StandardError;
            end

            error { raise "should not come here" }

            namespace('/en/:id') do
              error(CError) { 201 }
              get '/?' do
                raise CError
              end
            end
          }

          get('/en/1').status.should == 201
        end
      end

      unless verb == :head
        describe 'templates' do
          specify 'default to the base app\'s template' do
            mock_app do
              template(:foo) { 'hi' }
              send(verb, '/') { erb :foo }
              namespace '/foo' do
                send(verb) { erb :foo }
              end
            end

            send(verb, '/').body.should eq 'hi'
            send(verb, '/foo').body.should eq 'hi'
          end

          specify 'can be nested' do
            mock_app do
              template(:foo) { 'hi' }
              send(verb, '/') { erb :foo }
              namespace '/foo' do
                template(:foo) { 'ho' }
                send(verb) { erb :foo }
              end
            end

            send(verb, '/').body.should eq 'hi'
            send(verb, '/foo').body.should eq 'ho'
          end

          specify 'can use a custom views directory' do
            mock_app do
              set :views, File.expand_path('../namespace', __FILE__)
              send(verb, '/') { erb :foo }
              namespace('/foo') do
                set :views, File.expand_path('../namespace/nested', __FILE__)
                send(verb) { erb :foo }
              end
            end

            send(verb, '/').body.should eq "hi\n"
            send(verb, '/foo').body.should eq "ho\n"
          end

          specify 'default to the base app\'s layout' do
            mock_app do
              layout { 'he said: <%= yield %>' }
              template(:foo) { 'hi' }
              send(verb, '/') { erb :foo }
              namespace '/foo' do
                template(:foo) { 'ho' }
                send(verb) { erb :foo }
              end
            end

            send(verb, '/').body.should eq 'he said: hi'
            send(verb, '/foo').body.should eq 'he said: ho'
          end

          specify 'can define nested layouts' do
            mock_app do
              layout { 'Hello <%= yield %>!' }
              template(:foo) { 'World' }
              send(verb, '/') { erb :foo }
              namespace '/foo' do
                layout { 'Hi <%= yield %>!' }
                send(verb) { erb :foo }
              end
            end

            send(verb, '/').body.should eq 'Hello World!'
            send(verb, '/foo').body.should eq 'Hi World!'
          end
        end
      end

      describe 'extensions' do
        specify 'provide read access to settings' do
          value = nil
          mock_app do
            set :foo, 42
            namespace '/foo' do
              value = foo
            end
          end
          value.should eq 42
        end

        specify 'can be registered within a namespace' do
          a = b = nil
          extension = Module.new { define_method(:views) { 'CUSTOM!!!' } }
          mock_app do
            namespace '/' do
              register extension
              a = views
            end
            b = views
          end
          a.should eq 'CUSTOM!!!'
          b.should_not eq 'CUSTOM!!!'
        end

        specify 'trigger the route_added hook' do
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
          route[1].should eq '/foo'
        end

        specify 'prevent app-global settings from being changed' do
          proc { namespace('/') { set :foo, :bar }}.should raise_error
        end
      end
    end
  end

  describe 'settings' do
    it 'provides access to top-level settings' do
      mock_app do
        set :foo, 'ok'

        namespace '/foo' do
          get '/bar' do
            settings.foo
          end
        end
      end

      get('/foo/bar').status.should == 200
      last_response.body.should == 'ok'
    end

    it 'uses some repro' do
      mock_app do
        set :foo, 42

        namespace '/foo' do
          get '/bar' do
            #settings.respond_to?(:foo).to_s
            settings.foo.to_s
          end
        end
      end

      get('/foo/bar').status.should == 200
      last_response.body.should == '42'
    end

    it 'allows checking setting existence with respond_to?' do
      mock_app do
        set :foo, 42

        namespace '/foo' do
          get '/bar' do
            settings.respond_to?(:foo).to_s
          end
        end
      end

      get('/foo/bar').status.should == 200
      last_response.body.should == 'true'
    end
  end
end
