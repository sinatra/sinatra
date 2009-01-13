require File.dirname(__FILE__) + '/helper'

describe "Filters" do
  it "executes filters in the order defined" do
    count = 0
    mock_app do
      get('/') { 'Hello World' }
      before {
        count.should.be 0
        count = 1
      }
      before {
        count.should.be 1
        count = 2
      }
    end

    get '/'
    should.be.ok
    count.should.be 2
    body.should.equal 'Hello World'
  end

  it "allows filters to modify the request" do
    mock_app {
      get('/foo') { 'foo' }
      get('/bar') { 'bar' }
      before { request.path_info = '/bar' }
    }

    get '/foo'
    should.be.ok
    body.should.be == 'bar'
  end
end
