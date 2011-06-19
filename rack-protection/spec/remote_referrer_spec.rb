require File.expand_path('../spec_helper.rb', __FILE__)

describe Rack::Protection::RemoteReferrer do
  it_behaves_like "any rack application"
  it "accepts post requests with no referrer"
  it "accepts post requests with a local referrer"
  it "denies post requests with a remote referrer"
end
