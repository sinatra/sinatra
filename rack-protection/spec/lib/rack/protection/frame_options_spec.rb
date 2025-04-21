# frozen_string_literal: true

RSpec.describe Rack::Protection::FrameOptions do
  it_behaves_like 'any rack application'

  it 'should set the X-Frame-Options' do
    expect(get('/', {}, 'wants' => 'text/html').headers['X-Frame-Options']).to eq('SAMEORIGIN')
  end

  it 'should not set the X-Frame-Options for other content types' do
    expect(get('/', {}, 'wants' => 'text/foo').headers['X-Frame-Options']).to be_nil
  end

  it 'should allow changing the protection mode' do
    # I have no clue what other modes are available
    mock_app do
      use Rack::Protection::FrameOptions, frame_options: :deny
      run DummyApp
    end

    expect(get('/', {}, 'wants' => 'text/html').headers['X-Frame-Options']).to eq('DENY')
  end

  it 'should allow changing the protection mode to a string' do
    # I have no clue what other modes are available
    mock_app do
      use Rack::Protection::FrameOptions, frame_options: 'ALLOW-FROM foo'
      run DummyApp
    end

    expect(get('/', {}, 'wants' => 'text/html').headers['X-Frame-Options']).to eq('ALLOW-FROM foo')
  end

  it 'should not override the header if already set' do
    if Rack::RELEASE >= '3.0'
      headers = { 'x-frame-options' => 'allow' }
    else
      headers = { 'X-Frame-Options' => 'allow' }
    end

    mock_app with_headers(headers)
    expect(get('/', {}, 'wants' => 'text/html').headers['X-Frame-Options']).to eq('allow')
  end
end
