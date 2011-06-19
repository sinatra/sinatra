require File.expand_path('../spec_helper.rb', __FILE__)

describe Rack::Protection::RemoteToken do
  it_behaves_like "any rack application"
  it "accepts post requests with no referrer"
  it "accepts post requests with a local referrer"
  it "denies post requests with a remote referrer and no token"
  it "accepts post requests with a remote referrer and correct X-CSRF-Token header"
  it "denies post requests with a remote referrer and wrong X-CSRF-Token header"
  it "accepts post form requests with a remote referrer and correct authenticity_token field"
  it "denies post form requests with a remote referrer and wrong authenticity_token field"
end
