require File.expand_path('../spec_helper.rb', __FILE__)

describe Rack::Protection::AuthenticityToken do
  it_behaves_like "any rack application"
end
