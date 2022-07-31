# frozen_string_literal: true

RSpec.describe Rack::Protection::RemoteToken do
  let(:token) { described_class.random_token }
  let(:masked_token) { described_class.token(session) }
  let(:bad_token) { Base64.strict_encode64('badtoken') }
  let(:session) { { csrf: token } }

  it_behaves_like 'any rack application'

  it 'accepts post requests with no referrer' do
    expect(post('/')).to be_ok
  end

  it 'accepts post requests with a local referrer' do
    expect(post('/', {}, 'HTTP_REFERER' => '/')).to be_ok
  end

  it 'denies post requests with a remote referrer and no token' do
    post('/', {}, 'HTTP_REFERER' => 'http://example.com/foo', 'HTTP_HOST' => 'example.org')
    expect(last_response).not_to be_ok
  end

  it 'accepts post requests with a remote referrer and correct X-CSRF-Token header' do
    post('/', {}, 'HTTP_REFERER' => 'http://example.com/foo', 'HTTP_HOST' => 'example.org',
                  'rack.session' => session, 'HTTP_X_CSRF_TOKEN' => token)
    expect(last_response).to be_ok
  end

  it 'accepts post requests with a remote referrer and masked X-CSRF-Token header' do
    post('/', {}, 'HTTP_REFERER' => 'http://example.com/foo', 'HTTP_HOST' => 'example.org',
                  'rack.session' => session, 'HTTP_X_CSRF_TOKEN' => masked_token)
    expect(last_response).to be_ok
  end

  it 'denies post requests with a remote referrer and wrong X-CSRF-Token header' do
    post('/', {}, 'HTTP_REFERER' => 'http://example.com/foo', 'HTTP_HOST' => 'example.org',
                  'rack.session' => session, 'HTTP_X_CSRF_TOKEN' => bad_token)
    expect(last_response).not_to be_ok
  end

  it 'accepts post form requests with a remote referrer and correct authenticity_token field' do
    post('/', { 'authenticity_token' => token }, 'HTTP_REFERER' => 'http://example.com/foo',
                                                 'HTTP_HOST' => 'example.org', 'rack.session' => session)
    expect(last_response).to be_ok
  end

  it 'accepts post form requests with a remote referrer and masked authenticity_token field' do
    post('/', { 'authenticity_token' => masked_token }, 'HTTP_REFERER' => 'http://example.com/foo',
                                                        'HTTP_HOST' => 'example.org', 'rack.session' => session)
    expect(last_response).to be_ok
  end

  it 'denies post form requests with a remote referrer and wrong authenticity_token field' do
    post('/', { 'authenticity_token' => bad_token }, 'HTTP_REFERER' => 'http://example.com/foo',
                                                     'HTTP_HOST' => 'example.org', 'rack.session' => session)
    expect(last_response).not_to be_ok
  end
end
