require 'test/spec'
require 'sinatra/base'
require 'sinatra/test'

describe "HAML Templates" do
  include Sinatra::Test

  def haml_app(&block)
    mock_app {
      set :views, File.dirname(__FILE__) + '/views'
      get '/', &block
    }
    get '/'
  end

  it 'renders inline HAML strings' do
    haml_app { haml '%h1 Hiya' }
    should.be.ok
    body.should.equal "<h1>Hiya</h1>\n"
  end

  it 'renders .haml files in views path' do
    haml_app { haml :hello }
    should.be.ok
    body.should.equal "<h1>Hello From Haml</h1>\n"
  end

  it "renders with inline layouts" do
    mock_app {
      layout { %q(%h1= 'THIS. IS. ' + yield.upcase) }
      get('/') { haml '%em Sparta' }
    }
    get '/'
    should.be.ok
    body.should.equal "<h1>THIS. IS. <EM>SPARTA</EM></h1>\n"
  end

  it "renders with file layouts" do
    haml_app {
      haml 'Hello World', :layout => :layout2
    }
    should.be.ok
    body.should.equal "<h1>HAML Layout!</h1>\n<p>Hello World</p>\n"
  end

  it "raises error if template not found" do
    mock_app {
      get('/') { haml :no_such_template }
    }
    lambda { get('/') }.should.raise(Errno::ENOENT)
  end

  it "passes HAML options to the Haml engine" do
    haml_app {
      haml "!!!\n%h1 Hello World", :options => {:format => :html5}
    }
    should.be.ok
    body.should.equal "<!DOCTYPE html>\n<h1>Hello World</h1>\n"
  end

  it "passes default HAML options to the Haml engine" do
    mock_app {
      set :haml, {:format => :html5}
      get '/' do
        haml "!!!\n%h1 Hello World"
      end
    }
    get '/'
    should.be.ok
    body.should.equal "<!DOCTYPE html>\n<h1>Hello World</h1>\n"
  end
end
