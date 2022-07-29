# frozen_string_literal: true

RSpec.describe Rack::Protection::FormToken do
  let(:token) { described_class.random_token }
  let(:masked_token) { described_class.token(session) }
  let(:bad_token) { Base64.strict_encode64('badtoken') }
  let(:session) { { csrf: token } }

  it_behaves_like 'any rack application'

  it 'denies post requests without any token' do
    expect(post('/')).not_to be_ok
  end

  it 'accepts post requests with correct X-CSRF-Token header' do
    post('/', {}, 'rack.session' => session, 'HTTP_X_CSRF_TOKEN' => token)
    expect(last_response).to be_ok
  end

  it 'accepts post requests with masked X-CSRF-Token header' do
    post('/', {}, 'rack.session' => session, 'HTTP_X_CSRF_TOKEN' => masked_token)
    expect(last_response).to be_ok
  end

  it 'denies post requests with wrong X-CSRF-Token header' do
    post('/', {}, 'rack.session' => session, 'HTTP_X_CSRF_TOKEN' => bad_token)
    expect(last_response).not_to be_ok
  end

  it 'accepts post form requests with correct authenticity_token field' do
    post('/', { 'authenticity_token' => token }, 'rack.session' => session)
    expect(last_response).to be_ok
  end

  it 'accepts post form requests with masked authenticity_token field' do
    post('/', { 'authenticity_token' => masked_token }, 'rack.session' => session)
    expect(last_response).to be_ok
  end

  it 'denies post form requests with wrong authenticity_token field' do
    post('/', { 'authenticity_token' => bad_token }, 'rack.session' => session)
    expect(last_response).not_to be_ok
  end

  it 'accepts ajax requests without a valid token' do
    expect(post('/', {}, 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest')).to be_ok
  end
end
