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
    yajl_app { yajl 'json = { :foo => "bar" }' }
    assert ok?
    assert_body '{"foo":"bar"}'
  end
  
  it 'renders .yajl files in views path' do
    yajl_app { yajl :hello }
    assert ok?
    assert_body '{"yajl":"hello"}'
  end
  
  it 'raises error if template not found' do
    mock_app {
      get('/') { yajl :no_such_template }
    }
    assert_raise(Errno::ENOENT) { get('/') }
  end
  
  it 'accepts a :locals option' do
    yajl_app {
      locals = {:object => {:foo => 'bar'} }
      yajl 'json = object', :locals => locals
    }
    assert ok?
    assert_body '{"foo":"bar"}'
  end
  
  it 'decorates the json with a callback' do
    yajl_app {
      yajl 'json = { :foo => "bar" }', { :callback => 'baz' }
    }
    assert ok?
    assert_body 'baz({"foo":"bar"});'
  end
  
  it 'decorates the json with a variable' do
    yajl_app {
      yajl 'json = { :foo => "bar" }', { :variable => 'qux' } 
    }
    assert ok?
    assert_body 'var qux = {"foo":"bar"};'
  end
end

rescue LoadError
  warn "#{$!.to_s}: skipping yajl tests"
end  
