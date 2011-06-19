require File.expand_path('../spec_helper.rb', __FILE__)

describe Rack::Protection::SessionHijacking do
  it_behaves_like "any rack application"
  it "accepts a session without changes to tracked parameters"
  it "denies requests with a changing User-Agent header"
  it "denies requests with a changing Accept-Encoding header"
  it "denies requests with a changing Accept-Language header"
  it "denies requests with a changing Version header"
end
