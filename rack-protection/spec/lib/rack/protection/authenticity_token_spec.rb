require 'spec_helper'

describe Rack::Protection::AuthenticityToken do
  it_behaves_like "any rack application"

  it "denies post requests without any token" do
    expect(post('/')).not_to be_ok
  end

  it "accepts post requests with correct X-CSRF-Token header" do
    post('/', {}, 'rack.session' => {:csrf => "a"}, 'HTTP_X_CSRF_TOKEN' => "a")
    expect(last_response).to be_ok
  end

  it "denies post requests with wrong X-CSRF-Token header" do
    post('/', {}, 'rack.session' => {:csrf => "a"}, 'HTTP_X_CSRF_TOKEN' => "b")
    expect(last_response).not_to be_ok
  end

  it "accepts post form requests with correct authenticity_token field" do
    post('/', {"authenticity_token" => "a"}, 'rack.session' => {:csrf => "a"})
    expect(last_response).to be_ok
  end

  it "denies post form requests with wrong authenticity_token field" do
    post('/', {"authenticity_token" => "a"}, 'rack.session' => {:csrf => "b"})
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

    post('/', {"csrf_param" => "a"}, 'rack.session' => {:csrf => "a"})
    expect(last_response).to be_ok
  end

  it "sets a new csrf token for the session in env, even after a 'safe' request" do
    get('/', {}, {})
    expect(env['rack.session'][:csrf]).not_to be_nil
  end
end
