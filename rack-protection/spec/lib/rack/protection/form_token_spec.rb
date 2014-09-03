require 'spec_helper'

describe Rack::Protection::FormToken do
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

  it "accepts ajax requests without a valid token" do
    expect(post('/', {}, "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest")).to be_ok
  end
end
