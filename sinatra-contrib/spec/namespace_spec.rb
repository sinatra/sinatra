require 'spec_helper'

RSpec.describe Sinatra::Namespace do
  verbs = [:get, :head, :post, :put, :delete, :options, :patch]

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
        expect(send(verb, '/foo/bar')).to be_ok
        expect(body).to eq('baz') unless verb == :head
        expect(send(verb, '/foo/baz')).not_to be_ok
      end

      describe 'redirect_to' do
        it 'redirect within namespace' do
          namespace('/foo') { send(verb, '/bar') { redirect_to '/foo_bar' }}
          expect(send(verb, '/foo/bar')).to be_redirect
          expect(send(verb, '/foo/bar').location).to include("/foo/foo_bar")
        end
      end

      context 'when namespace is a string' do
        it 'accepts routes with no path' do
          namespace('/foo') { send(verb) { 'bar' } }
          expect(send(verb, '/foo')).to be_ok
          expect(body).to eq('bar') unless verb == :head
        end

        it 'accepts the path as a named parameter' do
          namespace('/foo') { send(verb, '/:bar') { params[:bar] }}
          expect(send(verb, '/foo/bar')).to be_ok
          expect(body).to eq('bar') unless verb == :head
          expect(send(verb, '/foo/baz')).to be_ok
          expect(body).to eq('baz') unless verb == :head
        end

        it 'accepts the path as a regular expression' do
          namespace('/foo') { send(verb, /\/\d\d/) { 'bar' }}
          expect(send(verb, '/foo/12')).to be_ok
          expect(body).to eq 'bar' unless verb == :head
          expect(send(verb, '/foo/123')).not_to be_ok
        end
      end

      context 'when namespace is a named parameter' do
        it 'accepts routes with no path' do
          namespace('/:foo') { send(verb) { 'bar' } }
          expect(send(verb, '/foo')).to be_ok
          expect(body).to eq('bar') unless verb == :head
        end

        it 'sets the parameter correctly' do
          namespace('/:foo') { send(verb, '/bar') { params[:foo] }}
          expect(send(verb, '/foo/bar')).to be_ok
          expect(body).to eq('foo') unless verb == :head
          expect(send(verb, '/fox/bar')).to be_ok
          expect(body).to eq('fox') unless verb == :head
          expect(send(verb, '/foo/baz')).not_to be_ok
        end

        it 'accepts the path as a named parameter' do
          namespace('/:foo') { send(verb, '/:bar') { params[:bar] }}
          expect(send(verb, '/foo/bar')).to be_ok
          expect(body).to eq('bar') unless verb == :head
          expect(send(verb, '/foo/baz')).to be_ok
          expect(body).to eq('baz') unless verb == :head
        end

        it 'accepts the path as regular expression' do
          namespace('/:foo') { send(verb, %r{/bar}) { params[:foo] }}
          expect(send(verb, '/foo/bar')).to be_ok
          expect(body).to eq('foo') unless verb == :head
          expect(send(verb, '/fox/bar')).to be_ok
          expect(body).to eq('fox') unless verb == :head
          expect(send(verb, '/foo/baz')).not_to be_ok
        end
      end

      context 'when namespace is a regular expression' do
        it 'accepts routes with no path' do
          namespace(%r{/foo}) { send(verb) { 'bar' } }
          expect(send(verb, '/foo')).to be_ok
          expect(body).to eq('bar') unless verb == :head
        end

        it 'accepts the path as a named parameter' do
          namespace(%r{/foo}) { send(verb, '/:bar') { params[:bar] }}
          expect(send(verb, '/foo/bar')).to be_ok
          expect(body).to eq('bar') unless verb == :head
          expect(send(verb, '/foo/baz')).to be_ok
          expect(body).to eq('baz') unless verb == :head
        end

        it 'accepts the path as a regular expression' do
          namespace(/\/\d\d/) { send(verb, /\/\d\d/) { 'foo' }}
          expect(send(verb, '/23/12')).to be_ok
          expect(body).to eq('foo') unless verb == :head
          expect(send(verb, '/123/12')).not_to be_ok
        end

        describe "before/after filters" do
          it 'trigger before filter' do
            ran = false
            namespace(/\/foo\/([^\/&?]+)\/bar\/([^\/&?]+)\//) { before { ran = true };}

            send(verb, '/bar/')
            expect(ran).to eq(false)

            send(verb, '/foo/1/bar/1/')
            expect(ran).to eq(true)
          end

          it 'trigger after filter' do
            ran = false
            namespace(/\/foo\/([^\/&?]+)\/bar\/([^\/&?]+)\//) { after { ran = true };}

            send(verb, '/bar/')
            expect(ran).to eq(false)

            send(verb, '/foo/1/bar/1/')
            expect(ran).to eq(true)
          end
        end

        describe 'helpers' do
          it 'are defined using the helpers method' do
            namespace(/\/foo\/([^\/&?]+)\/bar\/([^\/&?]+)\//) do
              helpers do
                def foo
                  'foo'
                end
              end

              send verb, '' do
                foo.to_s
              end
            end

            expect(send(verb, '/foo/1/bar/1/')).to be_ok
            expect(body).to eq('foo') unless verb == :head
          end
        end
      end

      context 'when namespace is a splat' do
        it 'accepts the path as a splat' do
          namespace('/*') { send(verb, '/*') { params[:splat].join ' - ' }}
          expect(send(verb, '/foo/bar')).to be_ok
          expect(body).to eq('foo - bar') unless verb == :head
        end
      end

      describe 'before-filters' do
        specify 'are triggered' do
          ran = false
          namespace('/foo') { before { ran = true }}
          send(verb, '/foo')
          expect(ran).to be true
        end

        specify 'are not triggered for a different namespace' do
          ran = false
          namespace('/foo') { before { ran = true }}
          send(verb, '/fox')
          expect(ran).to be false
        end
      end

      describe 'after-filters' do
        specify 'are triggered' do
          ran = false
          namespace('/foo') { after { ran = true }}
          send(verb, '/foo')
          expect(ran).to be true
        end

        specify 'are not triggered for a different namespace' do
          ran = false
          namespace('/foo') { after { ran = true }}
          send(verb, '/fox')
          expect(ran).to be false
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
            expect(last_response).to be_ok
            expect(body).to eq('yes') unless verb == :head
            send(verb, '/', {}, 'HTTP_HOST' => 'example.org')
            expect(last_response).to be_ok
            expect(body).to eq('no') unless verb == :head
          end

          specify 'are accepted in the route definition' do
            namespace :host_name => 'example.com' do
              send(verb, '/foo', :provides => :txt) { 'ok' }
            end
            expect(send(verb, '/foo', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/plain')).to be_ok
            expect(send(verb, '/foo', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/html')).not_to be_ok
            expect(send(verb, '/foo', {}, 'HTTP_HOST' => 'example.org', 'HTTP_ACCEPT' => 'text/plain')).not_to be_ok
          end

          specify 'are accepted in the before-filter' do
            ran = false
            namespace :provides => :txt do
              before('/foo', :host_name => 'example.com') { ran = true }
              send(verb, '/*') { 'ok' }
            end
            send(verb, '/foo', {}, 'HTTP_HOST' => 'example.org', 'HTTP_ACCEPT' => 'text/plain')
            expect(ran).to be false
            send(verb, '/foo', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/html')
            expect(ran).to be false
            send(verb, '/bar', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/plain')
            expect(ran).to be false
            send(verb, '/foo', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/plain')
            expect(ran).to be true
          end

          specify 'are accepted in the after-filter' do
            ran = false
            namespace :provides => :txt do
              after('/foo', :host_name => 'example.com') { ran = true }
              send(verb, '/*') { 'ok' }
            end
            send(verb, '/foo', {}, 'HTTP_HOST' => 'example.org', 'HTTP_ACCEPT' => 'text/plain')
            expect(ran).to be false
            send(verb, '/foo', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/html')
            expect(ran).to be false
            send(verb, '/bar', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/plain')
            expect(ran).to be false
            send(verb, '/foo', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/plain')
            expect(ran).to be true
          end
        end

        context 'when the namespace is a string' do
          specify 'are accepted in the namespace' do
            namespace '/foo', :host_name => 'example.com' do
              send(verb) { 'ok' }
            end
            expect(send(verb, '/foo', {}, 'HTTP_HOST' => 'example.com')).to be_ok
            expect(send(verb, '/foo', {}, 'HTTP_HOST' => 'example.org')).not_to be_ok
          end

          specify 'are accepted in the before-filter' do
            namespace '/foo' do
              before { @yes = nil }
              before(:host_name => 'example.com') { @yes = 'yes' }
              send(verb) { @yes || 'no' }
            end
            send(verb, '/foo', {}, 'HTTP_HOST' => 'example.com')
            expect(last_response).to be_ok
            expect(body).to eq('yes') unless verb == :head
            send(verb, '/foo', {}, 'HTTP_HOST' => 'example.org')
            expect(last_response).to be_ok
            expect(body).to eq('no') unless verb == :head
          end

          specify 'are accepted in the after-filter' do
            ran = false
            namespace '/foo' do
              before(:host_name => 'example.com') { ran = true }
              send(verb) { 'ok' }
            end
            send(verb, '/foo', {}, 'HTTP_HOST' => 'example.org')
            expect(ran).to be false
            send(verb, '/foo', {}, 'HTTP_HOST' => 'example.com')
            expect(ran).to be true
          end

          specify 'are accepted in the route definition' do
            namespace '/foo' do
              send(verb, :host_name => 'example.com') { 'ok' }
            end
            expect(send(verb, '/foo', {}, 'HTTP_HOST' => 'example.com')).to be_ok
            expect(send(verb, '/foo', {}, 'HTTP_HOST' => 'example.org')).not_to be_ok
          end

          context 'when the namespace has a condition' do
            specify 'are accepted in the before-filter' do
              ran = false
              namespace '/', :provides => :txt do
                before(:host_name => 'example.com') { ran = true }
                send(verb) { 'ok' }
              end
              send(verb, '/', {}, 'HTTP_HOST' => 'example.org', 'HTTP_ACCEPT' => 'text/plain')
              expect(ran).to be false
              send(verb, '/', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/html')
              expect(ran).to be false
              send(verb, '/', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/plain')
              expect(ran).to be true
            end

            specify 'are accepted in the filters' do
              ran = false
              namespace '/f', :provides => :txt do
                before('oo', :host_name => 'example.com') { ran = true }
                send(verb, '/*') { 'ok' }
              end
              send(verb, '/foo', {}, 'HTTP_HOST' => 'example.org', 'HTTP_ACCEPT' => 'text/plain')
              expect(ran).to be false
              send(verb, '/foo', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/html')
              expect(ran).to be false
              send(verb, '/far', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/plain')
              expect(ran).to be false
              send(verb, '/foo', {}, 'HTTP_HOST' => 'example.com', 'HTTP_ACCEPT' => 'text/plain')
              expect(ran).to be true
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

          expect(send(verb, '/foo/bar')).to be_ok
          expect(body).to eq('42') unless verb == :head
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

          expect(send(verb, '/foo/bar')).to be_ok
          expect(body).to eq('42') unless verb == :head
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

          expect(send(verb, '/foo/bar')).to be_ok
          expect(body).to eq('42') unless verb == :head
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

          expect { send verb, '/' }.to raise_error(NameError)
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

          expect { send verb, '/' }.to raise_error(NameError)
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

          expect(send(verb, '/foo/bar')).to be_ok
          expect(body).to eq('42') unless verb == :head
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

          expect(send(verb, '/foo/bar')).to be_ok
          expect(body).to eq('23') unless verb == :head
        end
      end

      describe 'nesting' do
        it 'routes to nested namespaces' do
          namespace '/foo' do
            namespace '/bar' do
              send(verb, '/baz') { 'OKAY!!11!'}
            end
          end

          expect(send(verb, '/foo/bar/baz')).to be_ok
          expect(body).to eq('OKAY!!11!') unless verb == :head
        end

        it 'works correctly if deep nesting' do
          namespace '/a' do
            namespace '/b' do
              namespace '/c' do
                send(verb, '') { 'hey' }
              end
            end
          end

          expect(send(verb, '/a/b/c')).to be_ok
          expect(body).to eq('hey') unless verb == :head
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

          expect(send(verb, '/foo/bar/baz')).to be_ok
          expect(body).to eq('42') unless verb == :head
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

          expect { send verb, '/foo' }.to raise_error(NameError)
        end

        it 'accepts a nested namespace as a named parameter' do
          namespace('/:a') { namespace('/:b') { send(verb) { params[:a] }}}
          expect(send(verb, '/foo/bar')).to be_ok
          expect(body).to eq('foo') unless verb == :head
        end
      end

      describe 'error handling' do
        it 'can be customized using the not_found block' do
          namespace('/de') do
            not_found { 'nicht gefunden' }
          end
          expect(send(verb, '/foo').status).to eq 404
          expect(last_response.body).not_to    eq 'nicht gefunden' unless verb == :head
          expect(get('/en/foo').status).to     eq 404
          expect(last_response.body).not_to    eq 'nicht gefunden' unless verb == :head
          expect(get('/de/foo').status).to     eq 404
          expect(last_response.body).to        eq 'nicht gefunden' unless verb == :head
        end

        it 'can be customized for specific error codes' do
          namespace('/de') do
            error(404) { 'nicht gefunden' }
          end
          expect(send(verb, '/foo').status).to eq 404
          expect(last_response.body).not_to    eq 'nicht gefunden' unless verb == :head
          expect(get('/en/foo').status).to     eq 404
          expect(last_response.body).not_to    eq 'nicht gefunden' unless verb == :head
          expect(get('/de/foo').status).to     eq 404
          expect(last_response.body).to        eq 'nicht gefunden' unless verb == :head
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
          expect(send(verb, '/foo').status).to eq 404
          expect(last_response.body).to        eq 'not found...' unless verb == :head
          expect(get('/en/foo').status).to     eq 404
          expect(last_response.body).to        eq 'not found...' unless verb == :head
          expect(get('/de/foo').status).to     eq 404
          expect(last_response.body).to        eq 'nicht gefunden' unless verb == :head
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
          expect(get('/en/foo').status).to     eq 401
          expect(last_response.body).to        eq 'auth failed' unless verb == :head
          expect(get('/de/foo').status).to     eq 406
          expect(last_response.body).to        eq 'methode nicht erlaubt' unless verb == :head
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

          expect(get('/en/1').status).to eq(201)
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

            expect(send(verb, '/').body).to eq 'hi'
            expect(send(verb, '/foo').body).to eq 'hi'
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

            expect(send(verb, '/').body).to eq 'hi'
            expect(send(verb, '/foo').body).to eq 'ho'
          end

          specify 'can use a custom views directory' do
            mock_app do
              set :views, File.expand_path('namespace', __dir__)
              send(verb, '/') { erb :foo }
              namespace('/foo') do
                set :views, File.expand_path('namespace/nested', __dir__)
                send(verb) { erb :foo }
              end
            end

            expect(send(verb, '/').body).to eq "hi\n"
            expect(send(verb, '/foo').body).to eq "ho\n"
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

            expect(send(verb, '/').body).to eq 'he said: hi'
            expect(send(verb, '/foo').body).to eq 'he said: ho'
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

            expect(send(verb, '/').body).to eq 'Hello World!'
            expect(send(verb, '/foo').body).to eq 'Hi World!'
          end

          specify 'can render strings' do
            mock_app do
              namespace '/foo' do
                send(verb) { erb 'foo' }
              end
            end

            expect(send(verb, '/foo').body).to eq 'foo'
          end

          specify 'can render strings nested' do
            mock_app do
              namespace '/foo' do
                namespace '/bar' do
                  send(verb) { erb 'bar' }
                end
              end
            end

            expect(send(verb, '/foo/bar').body).to eq 'bar'
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
          expect(value).to eq 42
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
          expect(a).to eq 'CUSTOM!!!'
          expect(b).not_to eq 'CUSTOM!!!'
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
          expect(route[1]).to eq(Mustermann.new '/foo')
        end

        specify 'prevent app-global settings from being changed' do
          expect { namespace('/') { set :foo, :bar }}.to raise_error(ArgumentError)
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

      expect(get('/foo/bar').status).to eq(200)
      expect(last_response.body).to eq('ok')
    end

    it 'sets hashes correctly' do
      mock_app do
        namespace '/foo' do
          set erb: 'o', haml: 'k'
          get '/bar' do
            settings.erb + settings.haml
          end
        end
      end

      expect(get('/foo/bar').status).to eq(200)
      expect(last_response.body).to eq('ok')
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

      expect(get('/foo/bar').status).to eq(200)
      expect(last_response.body).to eq('42')
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

      expect(get('/foo/bar').status).to eq(200)
      expect(last_response.body).to eq('true')
    end

    it 'avoids executing filters even if prefix matches with other namespace' do
      mock_app do
        helpers do
          def dump_args(*args)
            args.inspect
          end
        end

        namespace '/foo' do
          helpers do
            def dump_args(*args)
              super(:foo, *args)
            end
          end
          get('') { dump_args }
        end

        namespace '/foo-bar' do
          helpers do
            def dump_args(*args)
              super(:foo_bar, *args)
            end
          end
          get('') { dump_args }
        end
      end

      get '/foo-bar'
      expect(last_response.body).to eq('[:foo_bar]')
    end
  end

  it 'forbids unknown engine settings' do
    expect {
      mock_app do
        namespace '/foo' do
          set :unknownsetting
        end
      end
    }.to raise_error(ArgumentError, 'may not set unknownsetting')
  end
end
