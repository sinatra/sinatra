require File.expand_path('../spec_helper.rb', __FILE__)

describe Rack::Protection::JsonCsrf do
  it_behaves_like "any rack application"
  it "denies get requests with json responses with a remote referrer"
  it "accepts get requests with json responses with a local referrer"
  it "accepts get requests with json responses with no referrer"
end
