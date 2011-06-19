require File.expand_path('../spec_helper.rb', __FILE__)

describe Rack::Protection::NoReferrer do
  it_behaves_like "any rack application"

  it "should not allow post request without a referrer" do
    post('/').should_not be_ok
  end

  it "should allow post request with a relative referrer" do
    post('/', {}, 'HTTP_REFERER' => '/').should be_ok
  end

  it "should allow post request with an absolute referrer" do
    post('/', {}, 'HTTP_REFERER' => 'http://google.com').should be_ok
  end

  it "should not allow post request with an empty referrer" do
    post('/', {}, 'HTTP_REFERER' => '').should_not be_ok
  end
end
