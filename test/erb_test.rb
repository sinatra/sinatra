require 'test/spec'
require 'sinatra/base'
require 'sinatra/test'

describe "ERB Templates" do
  include Sinatra::Test

  def erb_app(&block)
    mock_app {
      set :views, File.dirname(__FILE__) + '/views'
      get '/', &block
    }
    get '/'
  end

  it 'renders inline ERB strings' do
    erb_app { erb '<%= 1 + 1 %>' }
    should.be.ok
    body.should.equal '2'
  end

  it 'renders .erb files in views path' do
    erb_app { erb :hello }
    should.be.ok
    body.should.equal "Hello World\n"
  end

  it 'takes a :locals option' do
    erb_app {
      locals = {:foo => 'Bar'}
      erb '<%= foo %>', :locals => locals
    }
    should.be.ok
    body.should.equal 'Bar'
  end

  it "renders with inline layouts" do
    mock_app {
      layout { 'THIS. IS. <%= yield.upcase %>!' }
      get('/') { erb 'Sparta' }
    }
    get '/'
    should.be.ok
    body.should.equal 'THIS. IS. SPARTA!'
  end

  it "renders with file layouts" do
    erb_app {
      erb 'Hello World', :layout => :layout2
    }
    should.be.ok
    body.should.equal "ERB Layout!\nHello World\n"
  end

end
