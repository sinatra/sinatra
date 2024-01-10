# frozen_string_literal: true

RSpec.describe Rack::Protection::XSSHeader do
  it_behaves_like 'any rack application'

  it 'should set the X-XSS-Protection' do
    expect(get('/', {}, 'wants' => 'text/html;charset=utf-8').headers['X-XSS-Protection']).to eq('1; mode=block')
  end

  it 'should set the X-XSS-Protection for XHTML' do
    expect(get('/', {}, 'wants' => 'application/xhtml+xml').headers['X-XSS-Protection']).to eq('1; mode=block')
  end

  it 'should not set the X-XSS-Protection for other content types' do
    expect(get('/', {}, 'wants' => 'application/foo').headers['X-XSS-Protection']).to be_nil
  end

  it 'should allow changing the protection mode' do
    # I have no clue what other modes are available
    mock_app do
      use Rack::Protection::XSSHeader, xss_mode: :foo
      run DummyApp
    end

    expect(get('/', {}, 'wants' => 'application/xhtml').headers['X-XSS-Protection']).to eq('1; mode=foo')
  end

  it 'should not override the header if already set' do
    mock_app with_headers('x-xss-protection' => '0')
    expect(get('/', {}, 'wants' => 'text/html').headers['X-XSS-Protection']).to eq('0')
  end

  it 'should set the X-Content-Type-Options' do
    expect(get('/', {}, 'wants' => 'text/html').headers['X-Content-Type-Options']).to eq('nosniff')
  end

  it 'should set the X-Content-Type-Options for other content types' do
    expect(get('/', {}, 'wants' => 'application/foo').headers['X-Content-Type-Options']).to eq('nosniff')
  end

  it 'should allow changing the nosniff-mode off' do
    mock_app do
      use Rack::Protection::XSSHeader, nosniff: false
      run DummyApp
    end

    expect(get('/').headers['X-Content-Type-Options']).to be_nil
  end

  it 'should not override the header if already set X-Content-Type-Options' do
    mock_app with_headers('x-content-type-options' => 'sniff')
    expect(get('/', {}, 'wants' => 'text/html').headers['X-Content-Type-Options']).to eq('sniff')
  end
end
