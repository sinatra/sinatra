require File.expand_path('../helper', __FILE__)

begin
  require 'asciidoctor'

  class MultiViewTest < Minitest::Test
    def asciidoc_app_with_get(views=nil, &block)
      asciidoc_app(views, &block)
      get '/'
    end

    def asciidoc_app(views=nil, &block)
      mock_app do
        set :views, views
        get('/', &block)
      end
    end

    describe 'finding views' do
      describe 'with default :views setting' do
        it 'renders files in default path' do
          mock_app { get('/') { asciidoc :hello } }
          get '/'
          assert ok?
          assert_match %r{<h2.*?>Hello from AsciiDoc</h2>}, body
        end
      end
      describe 'with nil :views setting' do
        it 'renders files in default path' do
          asciidoc_app_with_get(nil) { asciidoc :hello }
          assert ok?
          assert_match %r{<h2.*?>Hello from AsciiDoc</h2>}, body
        end
      end
      describe 'with empty array :views setting' do
        @views = []
        it 'renders files in default path' do
          asciidoc_app_with_get([]) { asciidoc :hello }
          assert ok?
          assert_match %r{<h2.*?>Hello from AsciiDoc</h2>}, body
        end
      end
      describe 'should allow old-style single-value view path' do
        it 'renders files in views path' do
          asciidoc_app_with_get(:multi_view) { asciidoc :hello }
          assert ok?
          assert_match %r{<h2.*?>Default Hello</h2>}, body
        end
        it 'raises error if template not found' do
          asciidoc_app(:multi_view) { asciidoc :no_such_template }
          assert_raises(Errno::ENOENT) { get('/') }
        end
      end
      describe 'should allow array of view paths' do
        it 'renders files in views path' do
          asciidoc_app_with_get([:multi_view, :'multi_view/a', :'multi_view/b']) { asciidoc :hello }
          assert ok?
          assert_match %r{<h2.*?>Default Hello</h2>}, body
        end
        it 'raises error if template not found' do
          asciidoc_app([:multi_view, :'multi_view/a', :'multi_view/b']) { asciidoc :no_such_template }
          assert_raises(Errno::ENOENT) { get('/') }
        end
      end
      describe 'should search for files in array order' do
        it 'renders files in views path' do
          asciidoc_app_with_get([:'multi_view/b', :multi_view, :'multi_view/a']) { asciidoc :hello }
          assert ok?
          assert_match %r{<h2.*?>Hello from B</h2>}, body
        end
        it 'raises error if template not found' do
          asciidoc_app([:'multi_view/b', :multi_view, :'multi_view/a']) { asciidoc :no_such_template }
          assert_raises(Errno::ENOENT) { get('/') }
        end
      end
    end

    describe 'finding layouts' do
      describe 'with no view given' do
        it 'renders with file layouts' do
          asciidoc_app_with_get do
            asciidoc 'Hello World', :layout => :layout2, :layout_engine => :erb
          end
          assert ok?
          assert_include body, 'ERB Layout!'
          assert_include body, '<p>Hello World</p>'
        end
      end
      describe 'with a single symbol view given' do
        describe 'with no layout given' do
          it 'renders with default layout' do
            asciidoc_app_with_get(:multi_view) do
              asciidoc 'Hello World', :layout_engine => :erb
            end
            assert ok?
            assert_include body, 'Default Multi-View Layout'
            assert_include body, '<p>Hello World</p>'
          end
        end
        describe 'with layout given' do
          it 'renders with given layouts' do
            asciidoc_app_with_get(:multi_view) do
              asciidoc 'Hello World', :layout => :'a/layout', :layout_engine => :erb
            end
            assert ok?
            assert_include body, 'Multi-View Layout for A'
            assert_include body, '<p>Hello World</p>'
          end
        end
        describe 'with array of views' do
          it 'renders with given layouts' do
            asciidoc_app_with_get([:'multi_view/b', :'multi_view/a', :multi_view]) do
              asciidoc :test, :layout => :'layout', :layout_engine => :erb
            end
            assert ok?
            assert_include body, 'Multi-View Layout for B'
            assert_include body, 'TestFile!'
          end
        end
      end
    end

    describe 'using in partials' do
      describe 'with a single value for views' do
        it 'can be used in a nested fashion for partials and whatnot' do
          asciidoc_app_with_get(:multi_view) do
            erb '<outer><%= asciidoc :\'b/hello\' %></outer>'
          end
          assert ok?
          assert_include body, 'Default Multi-View Layout'
          assert_include body, 'Hello from B'
        end
      end
      describe 'with multiple view paths' do
        it 'can be used in a nested fashion for partials and whatnot' do
          asciidoc_app_with_get([:'multi_view/a', :multi_view, :'multi_view/b']) do
            erb '<outer><%= asciidoc :\'hello\' %></outer>'
          end
          assert ok?
          assert_include body, 'Multi-View Layout for A!'
          assert_include body, 'Hello from A'
        end
      end
    end
    describe 'All options together now!' do
      it 'works with layout specified and file rendered' do
        asciidoc_app_with_get([:'multi_view/a', :'multi_view/b', :multi_view]) do
          asciidoc :hello, :layout => :'b/layout', :layout_engine => :erb
        end
        assert ok?
        assert_include body, 'Multi-View Layout for B!'
        assert_include body, 'Hello from A'
      end
      it 'works with layout specified and string rendered' do
        asciidoc_app_with_get([:'multi_view/a', :'multi_view/b', :multi_view]) do
          erb '<outer><%= asciidoc :\'hello\' %></outer>', :layout => :'b/layout', :layout_engine => :erb
        end
        assert ok?
        assert_include body, 'Multi-View Layout for B!'
        assert_include body, 'Hello from A'
      end
    end
  end
rescue LoadError
  warn "#{$!.to_s}: skipping asciidoc tests"
end
