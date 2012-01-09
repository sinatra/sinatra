require File.expand_path('../helper', __FILE__)

begin
require 'yajl'
  
class YajlTest < Test::Unit::TestCase  
  def yajl_app(&block)
    mock_app {
      set :views, File.dirname(__FILE__) + '/views'
      get '/', &block
    }
    get '/'
  end
    
  it 'renders inline Yajl strings' do
    yajl_app { yajl "json = { :foo => 'bar'}" }
    assert ok?
    assert_body %({"foo":"bar"})
  end
  
  it 'renders .yajl files in views path' do
    yajl_app { yajl :hello }
    assert ok?
    assert_body %({"yajl":"hello"})
  end
end

rescue LoadError
  warn "#{$!.to_s}: skipping yajl tests"
end  
