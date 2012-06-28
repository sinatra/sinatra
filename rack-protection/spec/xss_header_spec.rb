require File.expand_path('../spec_helper.rb', __FILE__)

describe Rack::Protection::XSSHeader do
  it_behaves_like "any rack application"

  it 'should set the X-XSS-Protection' do
    get('/').headers["X-XSS-Protection"].should == "1; mode=block"
  end

  it 'should allow changing the protection mode' do
    # I have no clue what other modes are available
    mock_app do
      use Rack::Protection::XSSHeader, :xss_mode => :foo
      run DummyApp
    end

    get('/').headers["X-XSS-Protection"].should == "1; mode=foo"
  end

  it 'should not override the header if already set' do
    mock_app with_headers("X-XSS-Protection" => "0")
    get('/').headers["X-XSS-Protection"].should == "0"
  end

  it 'should set the X-Content-Type-Options' do
    get('/').header["X-Content-Type-Options"].should == "nosniff"
  end

  it 'should allow changing the nosniff-mode off' do
    mock_app do
      use Rack::Protection::XSSHeader, :nosniff => false
      run DummyApp
    end

    get('/').headers["X-Content-Type-Options"].should be_nil
  end

  it 'should not override the header if already set X-Content-Type-Options' do
    mock_app with_headers("X-Content-Type-Options" => "sniff")
    get('/').headers["X-Content-Type-Options"].should == "sniff"
  end
end
