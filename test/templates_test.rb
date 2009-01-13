require File.dirname(__FILE__) + '/helper'

describe 'Templating' do
  def render_app(&block)
    mock_app {
      def render_test(template, data, options, &block)
        inner = block ? block.call : ''
        data + inner
      end
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
    should.be.ok
    body.should.equal 'Hello World'
  end

  it 'renders Proc templates using the call result' do
    render_app { render :test, Proc.new {'Hello World'} }
    should.be.ok
    body.should.equal 'Hello World'
  end

  it 'looks up Symbol templates in views directory' do
    render_app { render :test, :hello }
    should.be.ok
    body.should.equal "Hello World!\n"
  end

  it 'uses the default layout template if not explicitly overridden' do
    with_default_layout do
      render_app { render :test, :hello }
      should.be.ok
      body.should.equal "Layout!\nHello World!\n"
    end
  end

  it 'uses the default layout template if not really overriden' do
    with_default_layout do
      render_app { render :test, :hello, :layout => true }
      should.be.ok
      body.should.equal "Layout!\nHello World!\n"
    end
  end

  it 'uses the layout template specified' do
    render_app { render :test, :hello, :layout => :layout2 }
    should.be.ok
    body.should.equal "Layout 2!\nHello World!\n"
  end

  it 'uses layout templates defined with the #template method' do
    render_app { render :test, :hello, :layout => :layout3 }
    should.be.ok
    body.should.equal "Layout 3!\nHello World!\n"
  end

  it 'loads templates from source file with use_in_file_templates!' do
    mock_app {
      use_in_file_templates!
    }
    @app.templates[:foo].should.equal "this is foo\n\n"
    @app.templates[:layout].should.equal "X\n= yield\nX\n"
  end
end

__END__

@@ foo
this is foo

@@ layout
X
= yield
X
