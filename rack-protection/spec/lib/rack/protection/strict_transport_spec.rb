# frozen_string_literal: true

RSpec.describe Rack::Protection::StrictTransport do
  it_behaves_like 'any rack application'

  it 'should set the Strict-Transport-Security header' do
    expect(get('/', {}, 'wants' => 'text/html').headers['Strict-Transport-Security']).to eq('max-age=31536000')
  end

  it 'should allow changing the max-age option' do
    mock_app do
      use Rack::Protection::StrictTransport, max_age: 16_070_400
      run DummyApp
    end

    expect(get('/', {}, 'wants' => 'text/html').headers['Strict-Transport-Security']).to eq('max-age=16070400')
  end

  it 'should allow switching on the include_subdomains option' do
    mock_app do
      use Rack::Protection::StrictTransport, include_subdomains: true
      run DummyApp
    end

    expect(get('/', {}, 'wants' => 'text/html').headers['Strict-Transport-Security']).to eq('max-age=31536000; includeSubDomains')
  end

  it 'should allow switching on the preload option' do
    mock_app do
      use Rack::Protection::StrictTransport, preload: true
      run DummyApp
    end

    expect(get('/', {}, 'wants' => 'text/html').headers['Strict-Transport-Security']).to eq('max-age=31536000; preload')
  end

  it 'should allow switching on all the options' do
    mock_app do
      use Rack::Protection::StrictTransport, preload: true, include_subdomains: true
      run DummyApp
    end

    expect(get('/', {}, 'wants' => 'text/html').headers['Strict-Transport-Security']).to eq('max-age=31536000; includeSubDomains; preload')
  end
end
