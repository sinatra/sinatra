require File.expand_path('../spec_helper.rb', __FILE__)

describe Rack::Protection::FrameOptions do
  it_behaves_like "any rack application"

  it 'should set the X-XSS-Protection' do
    get('/').headers["X-Frame-Options"].should == "sameorigin"
  end

  it 'should allow changing the protection mode' do
    # I have no clue what other modes are available
    mock_app do
      use Rack::Protection::FrameOptions, :frame_options => :deny
      run DummyApp
    end

    get('/').headers["X-Frame-Options"].should == "deny"
  end

  it 'should not override the header if already set' do
    mock_app with_headers("X-Frame-Options" => "allow")
    get('/').headers["X-Frame-Options"].should == "allow"
  end
end
