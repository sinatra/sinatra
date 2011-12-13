require File.expand_path('../helper', __FILE__)
begin
require 'coffee-script'
require 'execjs'
require 'haml'
require 'sass'

begin
  ExecJS.compile '1'
rescue Exception
  raise LoadError, 'unable to execute JavaScript'
end

class PreprocessTest < Test::Unit::TestCase
  def sinatra_app(options = {}, &block)
    mock_app {
      set :views, File.dirname(__FILE__) + '/views/preprocess'
      set(options)
      get '/', &block
    }
    get '/'
  end
  
  it 'renders coffee script with instance variable from file' do
    sinatra_app { @msg="\"Aye!\""; coffee :hello, :preprocess => :erb }
    assert ok?
    assert_include body, "alert(\"Aye!\");"
  end
  
  it 'renders coffee script with simple ruby inside' do
    sinatra_app { coffee :list, :preprocess => :erb }
    assert ok?
    assert_include body, "list = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]"
  end

  it 'renders inline with preprocess' do 
    sinatra_app { @msg="\"Aye!\""; coffee 'alert <%= @msg %>', :preprocess => :erb  }
    assert ok?
    assert_include body, "alert(\"Aye!\");"
  end
  
  it 'renders with layouts from file and preprocess' do
    sinatra_app { haml :something, :layout => :layout1, :preprocess => :erb }   
    assert ok?
    assert_equal "<h1>Welcome</h1>\n<p>\nhere\n</p>\n", body.gsub(/ /, '')
  end
  
  it "renders with inline layouts and preprocess" do
    mock_app {
      layout { %q(%h1= 'THIS. IS. ' + yield.upcase) }
      get('/') { haml '%em Sparta<%=1+1%>', :preprocess => :erb }
    }
    get '/'
    assert ok?
    assert_equal "<h1>THIS. IS. <EM>SPARTA2</EM></h1>\n", body
  end
end

rescue LoadError
  warn "#{$!.to_s}: skipping preprocess tests"
end
