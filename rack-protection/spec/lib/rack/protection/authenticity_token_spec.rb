describe Rack::Protection::AuthenticityToken do
  let(:token) { described_class.random_token }
  let(:bad_token) { described_class.random_token }
  let(:session) { {:csrf => token} }

  it_behaves_like "any rack application"

  it "denies post requests without any token" do
    expect(post('/')).not_to be_ok
  end

  it "accepts post requests with correct X-CSRF-Token header" do
    post('/', {}, 'rack.session' => session, 'HTTP_X_CSRF_TOKEN' => token)
    expect(last_response).to be_ok
  end

  it "accepts post requests with masked X-CSRF-Token header" do
    post('/', {}, 'rack.session' => session, 'HTTP_X_CSRF_TOKEN' => Rack::Protection::AuthenticityToken.token(session))
    expect(last_response).to be_ok
  end

  it "denies post requests with wrong X-CSRF-Token header" do
    post('/', {}, 'rack.session' => session, 'HTTP_X_CSRF_TOKEN' => bad_token)
    expect(last_response).not_to be_ok
  end

  it "accepts post form requests with correct authenticity_token field" do
    post('/', {"authenticity_token" => token}, 'rack.session' => session)
    expect(last_response).to be_ok
  end

  it "accepts post form requests with masked authenticity_token field" do
    post('/', {"authenticity_token" => Rack::Protection::AuthenticityToken.token(session)}, 'rack.session' => session)
    expect(last_response).to be_ok
  end

  it "denies post form requests with wrong authenticity_token field" do
    post('/', {"authenticity_token" => bad_token}, 'rack.session' => session)
    expect(last_response).not_to be_ok
  end

  it "prevents ajax requests without a valid token" do
    expect(post('/', {}, "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest")).not_to be_ok
  end

  it "allows for a custom authenticity token param" do
    mock_app do
      use Rack::Protection::AuthenticityToken, :authenticity_param => 'csrf_param'
      run proc { |e| [200, {'Content-Type' => 'text/plain'}, ['hi']] }
    end

    post('/', {"csrf_param" => token}, 'rack.session' => {:csrf => token})
    expect(last_response).to be_ok
  end

  it "sets a new csrf token for the session in env, even after a 'safe' request" do
    get('/', {}, {})
    expect(env['rack.session'][:csrf]).not_to be_nil
  end

  describe ".random_token" do
    it "outputs a base64 encoded 32 character string by default" do
      expect(Base64.strict_decode64(token).length).to eq(32)
    end

    it "outputs a base64 encoded string of the specified length" do
      token = described_class.random_token(64)
      expect(Base64.strict_decode64(token).length).to eq(64)
    end
  end

  describe ".mask_token" do
    it "generates unique masked values for a token" do
      first_masked_token =  described_class.mask_token(token)
      second_masked_token = described_class.mask_token(token)
      expect(first_masked_token).not_to eq(second_masked_token)
    end
  end

  describe ".unmask_decoded_token" do
    it "unmasks a token to its original decoded value" do
      masked_token = described_class.decode_token(described_class.mask_token(token))
      unmasked_token = described_class.unmask_decoded_token(masked_token)
      expect(unmasked_token).to eq(described_class.decode_token(token))
    end
  end
end
