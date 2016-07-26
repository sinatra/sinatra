require File.expand_path('../spec_helper.rb', __FILE__)

describe Rack::Protection::ContentSecurityPolicy do
  it_behaves_like "any rack application"

  it 'should set the Content Security Policy' do
    get('/', {}, 'wants' => 'text/html').headers["Content-Security-Policy"].should == "default-src none; script-src self; connect-src self; style-src self"
  end

  it 'should not set the Content Security Policy for other content types' do
    headers = get('/', {}, 'wants' => 'text/foo').headers
    headers["Content-Security-Policy"].should be_nil
    headers["Content-Security-Policy-Report-Only"].should be_nil
  end

  it 'should allow changing the protection settings' do
    mock_app do
      use Rack::Protection::ContentSecurityPolicy, :default_src => 'none', :script_src => 'https://cdn.mybank.net', :style_src => 'https://cdn.mybank.net', :img_src => 'https://cdn.mybank.net', :connect_src => 'https://api.mybank.com', :frame_src => 'self', :font_src => 'https://cdn.mybank.net', :object_src => 'https://cdn.mybank.net', :media_src => 'https://cdn.mybank.net', :report_uri => '/my_amazing_csp_report_parser', :sandbox => 'allow-scripts'

      run DummyApp
    end

    headers = get('/', {}, 'wants' => 'text/html').headers
    headers["Content-Security-Policy"].should == "default-src none; script-src https://cdn.mybank.net; connect-src https://api.mybank.com; font-src https://cdn.mybank.net; frame-src self; media-src https://cdn.mybank.net; style-src https://cdn.mybank.net; object-src https://cdn.mybank.net; report-uri /my_amazing_csp_report_parser; sandbox allow-scripts"
    headers["Content-Security-Policy-Report-Only"].should be_nil
  end

  it 'should allow changing report only' do
    # I have no clue what other modes are available
    mock_app do
      use Rack::Protection::ContentSecurityPolicy, :report_uri => '/my_amazing_csp_report_parser', :report_only => true
      run DummyApp
    end

    headers = get('/', {}, 'wants' => 'text/html').headers
    headers["Content-Security-Policy"].should be_nil
    headers["Content-Security-Policy-Report-Only"].should == "default-src none; script-src self; connect-src self; style-src self; report-uri /my_amazing_csp_report_parser"
  end

  it 'should not override the header if already set' do
    mock_app with_headers("Content-Security-Policy" => "default-src: none")
    get('/', {}, 'wants' => 'text/html').headers["Content-Security-Policy"].should == "default-src: none"
  end
end
