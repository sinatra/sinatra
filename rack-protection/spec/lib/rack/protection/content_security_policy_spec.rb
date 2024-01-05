# frozen_string_literal: true

RSpec.describe Rack::Protection::ContentSecurityPolicy do
  it_behaves_like 'any rack application'

  it 'should set the Content Security Policy' do
    expect(
      get('/', {}, 'wants' => 'text/html').headers['Content-Security-Policy']
    ).to eq("default-src 'self'")
  end

  it 'should not set the Content Security Policy for other content types' do
    headers = get('/', {}, 'wants' => 'text/foo').headers
    expect(headers['Content-Security-Policy']).to be_nil
    expect(headers['Content-Security-Policy-Report-Only']).to be_nil
  end

  it 'should allow changing the protection settings' do
    mock_app do
      use Rack::Protection::ContentSecurityPolicy, default_src: 'none', script_src: 'https://cdn.mybank.net', style_src: 'https://cdn.mybank.net', img_src: 'https://cdn.mybank.net', connect_src: 'https://api.mybank.com', frame_src: 'self', font_src: 'https://cdn.mybank.net', object_src: 'https://cdn.mybank.net', media_src: 'https://cdn.mybank.net', report_uri: '/my_amazing_csp_report_parser', sandbox: 'allow-scripts'

      run DummyApp
    end

    headers = get('/', {}, 'wants' => 'text/html').headers
    expect(headers['Content-Security-Policy']).to eq('connect-src https://api.mybank.com; default-src none; font-src https://cdn.mybank.net; frame-src self; img-src https://cdn.mybank.net; media-src https://cdn.mybank.net; object-src https://cdn.mybank.net; report-uri /my_amazing_csp_report_parser; sandbox allow-scripts; script-src https://cdn.mybank.net; style-src https://cdn.mybank.net')
    expect(headers['Content-Security-Policy-Report-Only']).to be_nil
  end

  it 'should allow setting CSP3 no arg directives' do
    mock_app do
      use Rack::Protection::ContentSecurityPolicy, block_all_mixed_content: true, disown_opener: true, upgrade_insecure_requests: true

      run DummyApp
    end

    headers = get('/', {}, 'wants' => 'text/html').headers
    expect(headers['Content-Security-Policy']).to eq("block-all-mixed-content; default-src 'self'; disown-opener; upgrade-insecure-requests")
  end

  it 'should ignore CSP3 no arg directives unless they are set to true' do
    mock_app do
      use Rack::Protection::ContentSecurityPolicy, block_all_mixed_content: false, disown_opener: 'false', upgrade_insecure_requests: 'foo'

      run DummyApp
    end

    headers = get('/', {}, 'wants' => 'text/html').headers
    expect(headers['Content-Security-Policy']).to eq("default-src 'self'")
  end

  it 'should allow changing report only' do
    # I have no clue what other modes are available
    mock_app do
      use Rack::Protection::ContentSecurityPolicy, report_uri: '/my_amazing_csp_report_parser', report_only: true
      run DummyApp
    end

    headers = get('/', {}, 'wants' => 'text/html').headers
    expect(headers['Content-Security-Policy']).to be_nil
    expect(headers['Content-Security-Policy-Report-Only']).to eq("default-src 'self'; report-uri /my_amazing_csp_report_parser")
  end

  it 'should not override the header if already set' do
    mock_app with_headers('content-security-policy' => 'default-src: none')
    expect(get('/', {}, 'wants' => 'text/html').headers['Content-Security-Policy']).to eq('default-src: none')
  end
end
