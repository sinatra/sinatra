require File.dirname(__FILE__) + '/helper'

describe 'Sinatra::Response' do
  before do
    @response = Sinatra::Response.new
  end

  it "initializes with 200, text/html, and empty body" do
    assert_equal 200, @response.status
    assert_equal 'text/html', @response['Content-Type']
    assert_equal [], @response.body
  end

  it 'uses case insensitive headers' do
    @response['content-type'] = 'application/foo'
    assert_equal 'application/foo', @response['Content-Type']
    assert_equal 'application/foo', @response['CONTENT-TYPE']
  end

  it 'writes to body' do
    @response.body = 'Hello'
    @response.write ' World'
    assert_equal 'Hello World', @response.body
  end

  [204, 304].each do |status_code|
    it "removes the Content-Type header and body when response status is #{status_code}" do
      @response.status = status_code
      @response.body = ['Hello World']
      assert_equal [status_code, {}, []], @response.finish
    end
  end
end
