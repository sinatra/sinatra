require File.expand_path('../spec_helper.rb', __FILE__)

describe Rack::Protection::FormToken do
  it_behaves_like "any rack application"
  it "denies post form requests without any token"
  it "accepts post form requests with correct authenticity_token field"
  it "denies post form requests with wrong authenticity_token field"
  it "accepts ajax requests without a valid token"
end
