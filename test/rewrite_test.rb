require File.dirname(__FILE__) + '/helper'

class RewriteTest < Test::Unit::TestCase
  
  it 'allows hash syntax' do
    mock_app {
      rewrite '/foo' => '/bar'
      get '/bar' do
        "Hello World"
      end
    }
    
    request = Rack::MockRequest.new(@app)
    response = request.request('GET', '/foo', {})
    assert response.ok?
    assert_equal 'Hello World', response.body
  end
  
  it 'allows multiple items in hash' do
    mock_app {
      rewrite '/foo' => '/bar', '/qux' => '/bar'
      get '/bar' do
        "Hello World"
      end
    }
    
    request = Rack::MockRequest.new(@app)
    resp1, resp2 = ['/foo','/qux'].map { |uri| request.request('GET', uri, {}) }
    assert resp1.ok? and resp2.ok?
    assert_equal resp1.body, resp2.body
  end
  
  it 'can rewrite using a block' do
    mock_app {
      rewrite '/:page', '/show/:page' do; "/page/#{params[:page]}"; end
      get '/page/:p' do
        "Viewing page: #{params[:p]}"
      end
    }
    
    request = Rack::MockRequest.new(@app)
    response = request.request('GET', '/foo', {})
    assert response.ok?
    assert_equal 'Viewing page: foo', response.body
    
    resp1, resp2 = ['/qux','/show/qux'].map { |uri| request.request('GET', uri, {}) }
    assert resp1.ok? and resp2.ok?
    assert_equal resp1.body, resp2.body
  end
  
  it 'will ignore the rewrite if the block returns false or nil' do
    mock_app {
      rewrite '/:page' do; "/page/#{params[:page]}" unless params[:page] == "test"; end
      get '/page/:p' do
        "Viewing page: #{params[:p]}"
      end
    }
    
    request = Rack::MockRequest.new(@app)
    response = request.request('GET', '/test', {})
    assert_equal 404, response.status
  end
end