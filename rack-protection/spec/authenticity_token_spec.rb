require File.expand_path('../spec_helper.rb', __FILE__)

describe Rack::Protection::AuthenticityToken do
  it_behaves_like "any rack application"
  it "denies post requests without any token"
  it "accepts post requests with correct X-CSRF-Token header"
  it "denies post requests with wrong X-CSRF-Token header"
  it "accepts post form requests with correct authenticity_token field"
  it "denies post form requests with wrong authenticity_token field"
  it "prevents ajax requests without a valid token"
end
