# frozen_string_literal: true

RSpec.describe Rack::Protection::AuthenticityToken do
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

  it 'accepts post form requests with a valid per form token' do
    token = Rack::Protection::AuthenticityToken.token(session, path: '/foo')
    post('/foo', { 'authenticity_token' => token }, 'rack.session' => session)
    expect(last_response).to be_ok
  end

  it 'denies post form requests with an invalid per form token' do
    token = Rack::Protection::AuthenticityToken.token(session, path: '/foo')
    post('/bar', { 'authenticity_token' => token }, 'rack.session' => session)
    expect(last_response).not_to be_ok
  end

  it 'prevents ajax requests without a valid token' do
    expect(post('/', {}, 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest')).not_to be_ok
  end

  it 'allows for a custom authenticity token param' do
    mock_app do
      use Rack::Protection::AuthenticityToken, authenticity_param: 'csrf_param'
      run proc { |_e| [200, { 'content-type' => 'text/plain' }, ['hi']] }
    end

    post('/', { 'csrf_param' => token }, 'rack.session' => { csrf: token })
    expect(last_response).to be_ok
  end

  it "sets a new csrf token for the session in env, even after a 'safe' request" do
    get('/', {}, {})
    expect(env['rack.session'][:csrf]).not_to be_nil
  end

  it 'allows for a custom token session key' do
    mock_app do
      use(Rack::Config) { |e| e['rack.session'] ||= {} }
      use Rack::Protection::AuthenticityToken, key: :_csrf
      run DummyApp
    end

    get '/'
    expect(env['rack.session'][:_csrf]).not_to be_nil
  end

  describe '.token' do
    it 'returns a unique masked version of the authenticity token' do
      expect(Rack::Protection::AuthenticityToken.token(session)).not_to eq(masked_token)
    end

    it 'sets a session authenticity token if one does not exist' do
      session = {}
      allow(Rack::Protection::AuthenticityToken).to receive(:random_token).and_return(token)
      allow_any_instance_of(Rack::Protection::AuthenticityToken).to receive(:mask_token).and_return(masked_token)
      Rack::Protection::AuthenticityToken.token(session)
      expect(session[:csrf]).to eq(token)
    end
  end

  describe '.random_token' do
    it 'generates a base64 encoded 32 character string' do
      expect(Base64.urlsafe_decode64(token).length).to eq(32)
    end
  end
end
