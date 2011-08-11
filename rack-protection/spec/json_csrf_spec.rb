require File.expand_path('../spec_helper.rb', __FILE__)

describe Rack::Protection::JsonCsrf do
  it_behaves_like "any rack application"

  describe 'json response' do
    before do
      mock_app { |e| [200, {'Content-Type' => 'application/json'}, []]}
    end

    it "denies get requests with json responses with a remote referrer" do
      get('/', {}, 'HTTP_REFERER' => 'http://evil.com').should_not be_ok
    end

    it "accepts get requests with json responses with a local referrer" do
      get('/', {}, 'HTTP_REFERER' => '/').should be_ok
    end

    it "accepts get requests with json responses with no referrer" do
      get('/', {}).should be_ok
    end
  end

  describe 'not json response' do

    it "accepts get requests with 304 headers" do
      mock_app { |e| [304, {}, []]}
      get('/', {}).status.should == 304
    end

  end
end
