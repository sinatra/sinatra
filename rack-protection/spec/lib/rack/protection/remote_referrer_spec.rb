# frozen_string_literal: true

RSpec.describe Rack::Protection::RemoteReferrer do
  it_behaves_like 'any rack application'

  it 'accepts post requests with no referrer' do
    expect(post('/')).to be_ok
  end

  it 'does not accept post requests with no referrer if allow_empty_referrer is false' do
    mock_app do
      use Rack::Protection::RemoteReferrer, allow_empty_referrer: false
      run DummyApp
    end
    expect(post('/')).not_to be_ok
  end

  it 'should allow post request with a relative referrer' do
    expect(post('/', {}, 'HTTP_REFERER' => '/')).to be_ok
  end

  it 'accepts post requests with the same host in the referrer' do
    post('/', {}, 'HTTP_REFERER' => 'http://example.com/foo', 'HTTP_HOST' => 'example.com')
    expect(last_response).to be_ok
  end

  it 'denies post requests with a remote referrer' do
    post('/', {}, 'HTTP_REFERER' => 'http://example.com/foo', 'HTTP_HOST' => 'example.org')
    expect(last_response).not_to be_ok
  end
end
