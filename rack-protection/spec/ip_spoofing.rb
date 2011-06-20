require File.expand_path('../spec_helper.rb', __FILE__)

describe Rack::Protection::IPSpoofing do
  it_behaves_like "any rack application"
  it 'accepts requests without X-Forward-For header'
  it 'accepts requests with proper X-Forward-For header'
  it 'denies requests where the client spoofs X-Forward-For but not the IP'
  it 'denies requests where the client spoofs the IP but not X-Forward-For'
  it 'denies requests where IP and X-Forward-For are spoofed but not X-Real-IP'
  it 'denies requests where X-Real-IP is spoofed'
end
