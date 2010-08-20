require './' + File.dirname(__FILE__) + '/helper'

class TestTemplate < Tilt::Template
  def prepare
  end
  alias compile! prepare # for tilt < 0.7

  def evaluate(scope, locals={}, &block)
    inner = block ? block.call : ''
    data + inner
  end

  Tilt.register 'test', self
end

class TemplatesTest < Test::Unit::TestCase
  def render_app(base=Sinatra::Base, &block)
    mock_app(base) {
      set :views, File.dirname(__FILE__) + '/views'
      get '/', &block
      template(:layout3) { "Layout 3!\n" }
    }
    get '/'
  end

  def with_default_layout
    layout = File.dirname(__FILE__) + '/views/layout.test'
    File.open(layout, 'wb') { |io| io.write "Layout!\n" }
    yield
  ensure
    File.unlink(layout) rescue nil
  end

  it 'renders String templates directly' do
    render_app { render :test, 'Hello World' }
    assert ok?
    assert_equal 'Hello World', body
  end

  it 'renders Proc templates using the call result' do
    render_app { render :test, Proc.new {'Hello World'} }
    assert ok?
    assert_equal 'Hello World', body
  end

  it 'looks up Symbol templates in views directory' do
    render_app { render :test, :hello }
    assert ok?
    assert_equal "Hello World!\n", body
  end

  it 'uses the default layout template if not explicitly overridden' do
    with_default_layout do
      render_app { render :test, :hello }
      assert ok?
      assert_equal "Layout!\nHello World!\n", body
    end
  end

  it 'uses the default layout template if not really overriden' do
    with_default_layout do
      render_app { render :test, :hello, :layout => true }
      assert ok?
      assert_equal "Layout!\nHello World!\n", body
    end
  end

  it 'uses the layout template specified' do
    render_app { render :test, :hello, :layout => :layout2 }
    assert ok?
    assert_equal "Layout 2!\nHello World!\n", body
  end

  it 'uses layout templates defined with the #template method' do
    render_app { render :test, :hello, :layout => :layout3 }
    assert ok?
    assert_equal "Layout 3!\nHello World!\n", body
  end

  it 'loads templates from source file' do
    mock_app { enable :inline_templates }
    assert_equal "this is foo\n\n", @app.templates[:foo][0]
    assert_equal "X\n= yield\nX\n", @app.templates[:layout][0]
  end

  it 'loads templates from given source file' do
    mock_app { set :inline_templates, __FILE__ }
    assert_equal "this is foo\n\n", @app.templates[:foo][0]
  end

  test 'inline_templates ignores IO errors' do
    assert_nothing_raised {
      mock_app {
        set :inline_templates, '/foo/bar'
      }
    }

    assert @app.templates.empty?
  end

  it 'loads templates from specified views directory' do
    render_app { render :test, :hello, :views => options.views + '/foo' }

    assert_equal "from another views directory\n", body
  end

  it 'passes locals to the layout' do
    mock_app {
      template :my_layout do
        'Hello <%= name %>!<%= yield %>'
      end

      get '/' do
        erb '<p>content</p>', { :layout => :my_layout }, { :name => 'Mike'}
      end
    }

    get '/'
    assert ok?
    assert_equal 'Hello Mike!<p>content</p>', body
  end

  it 'loads templates defined in subclasses' do
    base = Class.new(Sinatra::Base)
    base.template(:foo) { 'bar' }
    render_app(base) { render :test, :foo }
    assert ok?
    assert_equal 'bar', body
  end

  it 'uses templates in superclasses before subclasses' do
    base = Class.new(Sinatra::Base)
    base.template(:foo) { 'template in superclass' }
    assert_equal 'template in superclass', base.templates[:foo].first.call

    mock_app(base) {
      set :views, File.dirname(__FILE__) + '/views'
      template(:foo) { 'template in subclass' }
      get('/') { render :test, :foo }
    }
    assert_equal 'template in subclass', @app.templates[:foo].first.call

    get '/'
    assert ok?
    assert_equal 'template in subclass', body
  end
end

# __END__ : this is not the real end of the script.

__END__

@@ foo
this is foo

@@ layout
X
= yield
X
