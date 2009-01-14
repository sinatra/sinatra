require File.dirname(__FILE__) + '/helper'

describe "Filters" do
  it "executes filters in the order defined" do
    count = 0
    mock_app do
      get('/') { 'Hello World' }
      before {
        fail 'count != 0' if count != 0
        count = 1
      }
      before {
        fail 'count != 1' if count != 1
        count = 2
      }
    end

    get '/'
    assert ok?
    assert_equal 2, count
    assert_equal 'Hello World', body
  end

  it "allows filters to modify the request" do
    mock_app {
      get('/foo') { 'foo' }
      get('/bar') { 'bar' }
      before { request.path_info = '/bar' }
    }

    get '/foo'
    assert ok?
    assert_equal 'bar', body
  end
end
